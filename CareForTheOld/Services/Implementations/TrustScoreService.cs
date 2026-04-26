using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
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
    public async Task<decimal> GetUserScoreAsync(Guid userId, Guid circleId)
    {
        var score = await _context.TrustScores
            .Where(t => t.UserId == userId && t.CircleId == circleId)
            .Select(t => t.Score)
            .FirstOrDefaultAsync();

        return score;
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<TrustScore>> GetCircleRankingAsync(Guid circleId, int top = 20)
    {
        return await _context.TrustScores
            .Include(t => t.User)
            .Where(t => t.CircleId == circleId)
            .OrderByDescending(t => t.Score)
            .ThenByDescending(t => t.TotalHelps)
            .Take(top)
            .ToListAsync();
    }

    /// <inheritdoc />
    public async Task RecalculateAllScoresAsync()
    {
        var allScores = await _context.TrustScores
            .AsTracking()
            .ToListAsync();

        if (allScores.Count == 0)
        {
            _logger.LogInformation("没有信任评分记录需要重算");
            return;
        }

        foreach (var score in allScores)
        {
            await RecalculateSingleScoreAsync(score);
        }

        await _context.SaveChangesAsync();
        _logger.LogInformation("已完成 {Count} 条信任评分重算", allScores.Count);
    }

    /// <inheritdoc />
    public async Task OnHelpCompletedAsync(Guid helpRequestId, Guid responderId)
    {
        // 查找求助请求获取 CircleId
        var helpRequest = await _context.NeighborHelpRequests
            .FirstOrDefaultAsync(r => r.Id == helpRequestId);

        if (helpRequest == null) return;

        // Upsert TrustScore
        var score = await _context.TrustScores
            .AsTracking()
            .FirstOrDefaultAsync(t => t.UserId == responderId && t.CircleId == helpRequest.CircleId);

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

        await RecalculateSingleScoreAsync(score);
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "邻居 {ResponderId} 完成互助，评分已更新：Score={Score}",
            responderId, score.Score);
    }

    /// <summary>
    /// 重算单个信任评分
    /// </summary>
    private async Task RecalculateSingleScoreAsync(TrustScore score)
    {
        // 1. 统计完成互助次数
        var totalHelps = await _context.NeighborHelpRequests
            .CountAsync(r => r.ResponderId == score.UserId &&
                             r.CircleId == score.CircleId &&
                             r.Status == HelpRequestStatus.Accepted);

        // 2. 计算平均评分
        var avgRating = await _context.NeighborHelpRatings
            .Where(r => r.RateeId == score.UserId)
            .Join(_context.NeighborHelpRequests,
                rating => rating.HelpRequestId,
                help => help.Id,
                (rating, help) => new { rating.Rating, help.CircleId })
            .Where(x => x.CircleId == score.CircleId)
            .AverageAsync(x => (decimal?)x.Rating) ?? 0m;

        // 3. 计算响应率
        var totalNotified = await _context.HelpNotificationLogs
            .Where(h => h.UserId == score.UserId)
            .Join(_context.NeighborHelpRequests,
                log => log.HelpRequestId,
                help => help.Id,
                (log, help) => help.CircleId)
            .Where(circleId => circleId == score.CircleId)
            .CountAsync();

        var totalResponded = await _context.HelpNotificationLogs
            .Where(h => h.UserId == score.UserId && h.RespondedAt != null)
            .Join(_context.NeighborHelpRequests,
                log => log.HelpRequestId,
                help => help.Id,
                (log, help) => help.CircleId)
            .Where(circleId => circleId == score.CircleId)
            .CountAsync();

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
        score.LastCalculatedAt = DateTime.UtcNow;
        score.UpdatedAt = DateTime.UtcNow;
    }
}
