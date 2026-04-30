using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using Hangfire;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 信任评分服务 — 基于互助历史数据量化邻居可信度
/// 评分算法：AvgRating×8×0.4 + Min(TotalHelps/20,1)×100×0.3 + ResponseRate×100×0.3
/// </summary>
public class TrustScoreService : ITrustScoreService
{
    private readonly AppDbContext _context;
    private readonly ILogger<TrustScoreService> _logger;

    /// <summary>互助次数封顶值（超过此数不再加分），使用 AppConstants 统一管理</summary>
    private const int MaxHelpsCap = AppConstants.TrustScore.MaxHelpsCap;

    public TrustScoreService(
        AppDbContext context,
        ILogger<TrustScoreService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<decimal> GetUserScoreAsync(Guid userId, Guid circleId, CancellationToken cancellationToken = default)
    {
        var score = await _context.TrustScores
            .Where(t => t.UserId == userId && t.CircleId == circleId)
            .Select(t => t.Score)
            .FirstOrDefaultAsync(cancellationToken);

        return score;
    }

    /// <inheritdoc />
    public async Task<Dictionary<Guid, decimal>> GetUserScoresAsync(IEnumerable<Guid> userIds, Guid circleId, CancellationToken cancellationToken = default)
    {
        var userIdSet = userIds.ToHashSet();
        var scores = await _context.TrustScores
            .Where(t => t.CircleId == circleId && userIdSet.Contains(t.UserId))
            .Select(t => new { t.UserId, t.Score })
            .ToListAsync(cancellationToken);

        var result = userIdSet.ToDictionary(uid => uid, _ => 0m);
        foreach (var s in scores)
        {
            result[s.UserId] = s.Score;
        }
        return result;
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<TrustScore>> GetCircleRankingAsync(Guid circleId, int top = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default)
    {
        return await _context.TrustScores
            .Include(t => t.User)
            .Where(t => t.CircleId == circleId)
            .OrderByDescending(t => t.Score)
            .ThenByDescending(t => t.TotalHelps)
            .Take(top)
            .ToListAsync(cancellationToken);
    }

    /// <inheritdoc />
    // 重试策略参考 AppConstants.HangfireRetry
    [AutomaticRetry(Attempts = 2, DelaysInSeconds = new[] { 60 })]
    public async Task RecalculateAllScoresAsync(CancellationToken cancellationToken = default)
    {
        var allScores = await _context.TrustScores
            .AsTracking()
            .ToListAsync(cancellationToken);

        if (!allScores.Any())
        {
            _logger.LogInformation("没有信任评分记录需要重算");
            return;
        }

        // 批量预加载所有评分所需的统计数据，避免循环内 N+1 查询
        var userIds = allScores.Select(s => s.UserId).ToHashSet();
        var circleIds = allScores.Select(s => s.CircleId).ToHashSet();

        // 1. 每用户每圈子的完成互助次数
        var helpsCounts = await _context.NeighborHelpRequests
            .Where(r => userIds.Contains(r.ResponderId!.Value) &&
                        circleIds.Contains(r.CircleId) &&
                        r.Status == HelpRequestStatus.Accepted)
            .GroupBy(r => new { r.ResponderId, r.CircleId })
            .Select(g => new { g.Key.ResponderId, g.Key.CircleId, Count = g.Count() })
            .ToDictionaryAsync(x => (x.ResponderId!.Value, x.CircleId), x => x.Count, cancellationToken);

        // 2. 每用户每圈子的平均评分
        var avgRatings = await _context.NeighborHelpRatings
            .Where(r => userIds.Contains(r.RateeId))
            .Join(_context.NeighborHelpRequests,
                rating => rating.HelpRequestId,
                help => help.Id,
                (rating, help) => new { rating.RateeId, help.CircleId, rating.Rating })
            .Where(x => circleIds.Contains(x.CircleId))
            .GroupBy(x => new { x.RateeId, x.CircleId })
            .Select(g => new { g.Key.RateeId, g.Key.CircleId, Avg = g.Average(x => (decimal?)x.Rating) ?? 0m })
            .ToDictionaryAsync(x => (x.RateeId, x.CircleId), x => x.Avg, cancellationToken);

        // 3. 每用户每圈子的通知总数和响应数（合并为一次查询）
        var notificationStats = await _context.HelpNotificationLogs
            .Where(h => userIds.Contains(h.UserId))
            .Join(_context.NeighborHelpRequests,
                log => log.HelpRequestId,
                help => help.Id,
                (log, help) => new { log.UserId, help.CircleId, log.RespondedAt })
            .Where(x => circleIds.Contains(x.CircleId))
            .GroupBy(x => new { x.UserId, x.CircleId })
            .Select(g => new {
                g.Key.UserId, g.Key.CircleId,
                Total = g.Count(),
                Responded = g.Count(x => x.RespondedAt != null)
            })
            .ToDictionaryAsync(
                x => (x.UserId, x.CircleId),
                x => new { x.Total, x.Responded },
                cancellationToken);

        // 内存中计算所有评分（无需额外数据库查询）
        var now = DateTime.UtcNow;
        foreach (var score in allScores)
        {
            var key = (score.UserId, score.CircleId);
            var totalHelps = helpsCounts.GetValueOrDefault(key);
            var avgRating = avgRatings.GetValueOrDefault(key);
            var stats = notificationStats.GetValueOrDefault(key);
            var totalNotified = stats?.Total ?? 0;
            var totalResponded = stats?.Responded ?? 0;

            var responseRate = totalNotified > 0
                ? (decimal)totalResponded / totalNotified
                : 0m;

            var ratingPart = avgRating * AppConstants.TrustScore.RatingMultiplier * AppConstants.TrustScore.RatingWeight;
            var helpsPart = Math.Min((decimal)totalHelps / MaxHelpsCap, 1m) * 100m * AppConstants.TrustScore.HelpsWeight;
            var responsePart = responseRate * 100m * AppConstants.TrustScore.ResponseWeight;
            var finalScore = Math.Round(ratingPart + helpsPart + responsePart, 2);

            score.TotalHelps = totalHelps;
            score.AvgRating = Math.Round(avgRating, 2);
            score.ResponseRate = Math.Round(responseRate, 4);
            score.Score = finalScore;
            score.LastCalculatedAt = now;
            score.UpdatedAt = now;
        }

        await _context.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("已完成 {Count} 条信任评分重算", allScores.Count);
    }

    /// <inheritdoc />
    public async Task OnHelpCompletedAsync(Guid helpRequestId, Guid responderId, CancellationToken cancellationToken = default)
    {
        // 一次查询同时获取求助请求和对应的信任评分，避免两次 DB 往返
        var helpRequest = await _context.NeighborHelpRequests
            .FirstOrDefaultAsync(r => r.Id == helpRequestId, cancellationToken);

        if (helpRequest == null)
        {
            _logger.LogWarning("更新信任评分：求助请求 {HelpRequestId} 不存在", helpRequestId);
            return;
        }

        var score = await _context.TrustScores
            .AsTracking()
            .FirstOrDefaultAsync(t => t.UserId == responderId && t.CircleId == helpRequest.CircleId, cancellationToken);

        if (score == null)
        {
            score = new TrustScore
            {
                Id = Guid.NewGuid(),
                UserId = responderId,
                CircleId = helpRequest.CircleId,
                CreatedAt = DateTime.UtcNow,
            };
            _context.TrustScores.Add(score);
        }

        try
        {
            await RecalculateSingleScoreAsync(score, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            // 并发场景：另一个请求已创建了该用户的评分记录，重新查询后更新
            _logger.LogInformation("信任评分记录并发冲突，重新查询: 用户={UserId}, 圈子={CircleId}",
                responderId, helpRequest.CircleId);

            score = await _context.TrustScores
                .AsTracking()
                .FirstAsync(t => t.UserId == responderId && t.CircleId == helpRequest.CircleId, cancellationToken);

            await RecalculateSingleScoreAsync(score, cancellationToken);
            try
            {
                await _context.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException retryEx)
            {
                _logger.LogError(retryEx, "信任评分并发重试保存失败: 用户={UserId}, 圈子={CircleId}",
                    responderId, helpRequest.CircleId);
                throw;
            }
        }

        _logger.LogInformation(
            "邻居 {ResponderId} 完成互助，评分已更新：Score={Score}",
            responderId, score!.Score);
    }

    /// <summary>
    /// 重算单个信任评分
    /// </summary>
    private async Task RecalculateSingleScoreAsync(TrustScore score, CancellationToken cancellationToken)
    {
        // 1. 统计完成互助次数
        var totalHelps = await _context.NeighborHelpRequests
            .CountAsync(r => r.ResponderId == score.UserId &&
                             r.CircleId == score.CircleId &&
                             r.Status == HelpRequestStatus.Accepted, cancellationToken);

        // 2. 计算平均评分
        var avgRating = await _context.NeighborHelpRatings
            .Where(r => r.RateeId == score.UserId)
            .Join(_context.NeighborHelpRequests,
                rating => rating.HelpRequestId,
                help => help.Id,
                (rating, help) => new { rating.Rating, help.CircleId })
            .Where(x => x.CircleId == score.CircleId)
            .AverageAsync(x => (decimal?)x.Rating, cancellationToken) ?? 0m;

        // 3. 计算响应率
        var totalNotified = await _context.HelpNotificationLogs
            .Where(h => h.UserId == score.UserId)
            .Join(_context.NeighborHelpRequests,
                log => log.HelpRequestId,
                help => help.Id,
                (log, help) => help.CircleId)
            .Where(circleId => circleId == score.CircleId)
            .CountAsync(cancellationToken);

        var totalResponded = await _context.HelpNotificationLogs
            .Where(h => h.UserId == score.UserId && h.RespondedAt != null)
            .Join(_context.NeighborHelpRequests,
                log => log.HelpRequestId,
                help => help.Id,
                (log, help) => help.CircleId)
            .Where(circleId => circleId == score.CircleId)
            .CountAsync(cancellationToken);

        var responseRate = totalNotified > 0
            ? (decimal)totalResponded / totalNotified
            : 0m;

        // 4. 计算综合评分
        // AvgRating(1-5) × 8 → 归一化到 0-40 分，权重 40%
        // Min(TotalHelps/20, 1) × 100 → 归一化到 0-30 分，权重 30%
        // ResponseRate(0-1) × 100 → 归一化到 0-30 分，权重 30%
        var ratingPart = avgRating * AppConstants.TrustScore.RatingMultiplier * AppConstants.TrustScore.RatingWeight;
        var helpsPart = Math.Min((decimal)totalHelps / MaxHelpsCap, 1m) * 100m * AppConstants.TrustScore.HelpsWeight;
        var responsePart = responseRate * 100m * AppConstants.TrustScore.ResponseWeight;
        var finalScore = Math.Round(ratingPart + helpsPart + responsePart, 2);

        // 更新记录
        score.TotalHelps = totalHelps;
        score.AvgRating = Math.Round(avgRating, 2);
        score.ResponseRate = Math.Round(responseRate, 4);
        score.Score = finalScore;
        var now = DateTime.UtcNow;
        score.LastCalculatedAt = now;
        score.UpdatedAt = now;
    }
}
