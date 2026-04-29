using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 邻里圈服务实现
/// </summary>
public class NeighborCircleService : INeighborCircleService
{
    private readonly AppDbContext _context;
    private readonly ILogger<NeighborCircleService> _logger;

    /// <summary>邀请码有效期</summary>
    private static readonly TimeSpan _inviteCodeExpiration = TimeSpan.FromDays(AppConstants.InviteCode.ExpirationDays);

    public NeighborCircleService(AppDbContext context, ILogger<NeighborCircleService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<NeighborCircleResponse> CreateCircleAsync(Guid creatorId, CreateNeighborCircleRequest request, CancellationToken cancellationToken = default)
    {
        // 一个用户同一时间只能加入一个邻里圈
        if (await _context.NeighborCircleMembers.AnyAsync(m => m.UserId == creatorId, cancellationToken))
            throw new ArgumentException(ErrorMessages.NeighborCircle.AlreadyInCircleCreate);

        var creator = await _context.Users.FindAsync([creatorId], cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = request.CircleName,
            CenterLatitude = request.CenterLatitude,
            CenterLongitude = request.CenterLongitude,
            RadiusMeters = request.RadiusMeters,
            CreatorId = creatorId,
            InviteCode = GenerateInviteCode(),
            InviteCodeExpiresAt = DateTime.UtcNow.Add(_inviteCodeExpiration),
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        // 创建者自动加入圈子
        circle.Members.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = creatorId,
            Role = creator.Role,
            Status = NeighborCircleStatus.Approved,
            JoinedAt = DateTime.UtcNow
        });

        _context.NeighborCircles.Add(circle);

        try
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.NeighborCircle.AlreadyInCircleCreate);
        }

        _logger.LogInformation("邻里圈已创建：圈子 {CircleId}，圈主 {CreatorId}，名称 {CircleName}", circle.Id, creatorId, request.CircleName);
        return await BuildCircleResponse(circle.Id, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<NeighborCircleResponse?> GetMyCircleAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var membership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == userId, cancellationToken);

        if (membership == null)
            return null;

        return await BuildCircleResponse(membership.CircleId, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<NeighborCircleResponse> GetCircleAsync(Guid circleId, CancellationToken cancellationToken = default)
    {
        return await BuildCircleResponse(circleId, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<NeighborCircleResponse> JoinCircleByCodeAsync(Guid userId, JoinNeighborCircleRequest request, CancellationToken cancellationToken = default)
    {
        // 检查用户是否已在某个圈子中
        if (await _context.NeighborCircleMembers.AnyAsync(m => m.UserId == userId, cancellationToken))
            throw new ArgumentException(ErrorMessages.NeighborCircle.AlreadyInCircleJoin);

        var user = await _context.Users.FindAsync([userId], cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 根据邀请码查找活跃的圈子
        var circle = await _context.NeighborCircles
            .FirstOrDefaultAsync(c => c.InviteCode == request.InviteCode && c.IsActive, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborCircle.InvalidInviteCode);

        // 验证邀请码是否过期
        if (circle.InviteCodeExpiresAt is { } expiresAt && expiresAt < DateTime.UtcNow)
            throw new ArgumentException(ErrorMessages.NeighborCircle.InviteCodeExpired);

        // 检查成员上限
        var memberCount = await _context.NeighborCircleMembers
            .CountAsync(m => m.CircleId == circle.Id, cancellationToken);

        if (memberCount >= circle.MaxMembers)
            throw new ArgumentException(ErrorMessages.NeighborCircle.CircleFull);

        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = userId,
            Role = user.Role,
            Status = NeighborCircleStatus.Approved,
            JoinedAt = DateTime.UtcNow
        });

        try
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.NeighborCircle.AlreadyInCircleJoin);
        }

        _logger.LogInformation("用户 {UserId} 加入邻里圈：圈子 {CircleId}", userId, circle.Id);
        return await BuildCircleResponse(circle.Id, cancellationToken);
    }

    /// <inheritdoc />
    public async Task LeaveCircleAsync(Guid circleId, Guid userId, CancellationToken cancellationToken = default)
    {
        var circle = await _context.NeighborCircles
            .AsTracking()
            .Include(c => c.Members)
            .FirstOrDefaultAsync(c => c.Id == circleId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborCircle.CircleNotFound);

        var member = circle.Members.FirstOrDefault(m => m.UserId == userId)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborCircle.NotCircleMember);

        if (circle.CreatorId == userId)
        {
            // 创建者退出 → 解散整个圈子
            _context.NeighborCircleMembers.RemoveRange(circle.Members);
            circle.IsActive = false;
        }
        else
        {
            _context.NeighborCircleMembers.Remove(member);
        }

        await _context.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("用户 {UserId} 退出邻里圈：圈子 {CircleId}，是否圈主：{IsCreator}", userId, circleId, circle.CreatorId == userId);
    }

    /// <inheritdoc />
    public async Task<List<NeighborMemberResponse>> GetMembersAsync(Guid circleId, CancellationToken cancellationToken = default)
    {
        return await _context.NeighborCircleMembers
            .Include(m => m.User)
            .Where(m => m.CircleId == circleId)
            .Select(m => new NeighborMemberResponse
            {
                UserId = m.UserId,
                RealName = m.User != null ? m.User.RealName : string.Empty,
                Role = m.Role,
                Nickname = m.Nickname,
                AvatarUrl = m.User != null ? m.User.AvatarUrl : null,
                JoinedAt = m.JoinedAt
            })
            .ToListAsync(cancellationToken);
    }

    /// <inheritdoc />
    public async Task<List<NeighborMemberResponse>> GetNearbyMembersAsync(
        Guid circleId, double latitude, double longitude, double radiusMeters = AppConstants.NeighborCircle.DefaultMemberRadiusMeters, CancellationToken cancellationToken = default)
    {
        // 先获取圈子所有成员，再用最近位置记录计算距离
        var memberIds = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == circleId)
            .Select(m => m.UserId)
            .ToListAsync(cancellationToken);

        // 获取每个成员最近的位置记录
        var recentLocations = await _context.LocationRecords
            .GroupBy(l => l.UserId)
            .Where(g => memberIds.Contains(g.Key))
            .Select(g => g.OrderByDescending(l => l.RecordedAt).First())
            .ToListAsync(cancellationToken);

        // 粗筛 + Haversine 精算
        var nearbyUserIds = new List<Guid>();
        var distanceMap = new Dictionary<Guid, double>();

        // 经纬度粗筛阈值：1 度约 111 公里
        var (latThreshold, lngThreshold) = GeoHelper.CalculateDegreeThresholds(radiusMeters, latitude);

        foreach (var loc in recentLocations)
        {
            // 粗筛
            if (Math.Abs(loc.Latitude - latitude) > latThreshold ||
                Math.Abs(loc.Longitude - longitude) > lngThreshold)
                continue;

            // Haversine 精算
            var distance = GeoHelper.HaversineDistance(latitude, longitude, loc.Latitude, loc.Longitude);
            if (distance <= radiusMeters)
            {
                nearbyUserIds.Add(loc.UserId);
                distanceMap[loc.UserId] = distance;
            }
        }

        if (!nearbyUserIds.Any())
            return [];

        // 查询成员详情并附加距离
        var members = await _context.NeighborCircleMembers
            .Include(m => m.User)
            .Where(m => m.CircleId == circleId && nearbyUserIds.Contains(m.UserId))
            .Select(m => new NeighborMemberResponse
            {
                UserId = m.UserId,
                RealName = m.User != null ? m.User.RealName : string.Empty,
                Role = m.Role,
                Nickname = m.Nickname,
                AvatarUrl = m.User != null ? m.User.AvatarUrl : null,
                JoinedAt = m.JoinedAt
            })
            .ToListAsync(cancellationToken);

        // 附加距离信息
        foreach (var m in members)
        {
            m.DistanceMeters = distanceMap[m.UserId];
        }
        return members;
    }

    /// <inheritdoc />
    public async Task<List<NeighborCircleResponse>> SearchNearbyCirclesAsync(
        double latitude, double longitude, double radiusMeters = AppConstants.NeighborCircle.SearchRadiusMeters, int maxResults = AppConstants.NeighborCircle.SearchMaxResults, CancellationToken cancellationToken = default)
    {
        // 计算最大搜索范围阈值（取最大圈子半径 + 搜索半径对应的经纬度偏移）
        // 用于在数据库层面粗筛，避免加载所有活跃圈子到内存
        var maxExtendedRadius = radiusMeters + AppConstants.NeighborCircle.MaxCircleRadiusMeters;
        var (latThreshold, lngThreshold) = GeoHelper.CalculateDegreeThresholds(maxExtendedRadius, latitude);

        // 数据库层粗筛：只查经纬度在矩形范围内的活跃圈子
        var circles = await _context.NeighborCircles
            .Where(c => c.IsActive
                && c.CenterLatitude >= latitude - latThreshold
                && c.CenterLatitude <= latitude + latThreshold
                && c.CenterLongitude >= longitude - lngThreshold
                && c.CenterLongitude <= longitude + lngThreshold)
            .ToListAsync(cancellationToken);

        var results = new List<(NeighborCircle Circle, double Distance)>();

        foreach (var circle in circles)
        {
            // Haversine 精算：搜索点到圈子中心距离
            var distToCenter = GeoHelper.HaversineDistance(latitude, longitude, circle.CenterLatitude, circle.CenterLongitude);

            // 搜索点在圈子覆盖范围内，或搜索半径与圈子范围有交集
            if (distToCenter <= radiusMeters + circle.RadiusMeters)
            {
                results.Add((circle, distToCenter));
            }
        }

        // 按距离排序后取 Top N，避免返回过多结果
        var topResults = results
            .OrderBy(r => r.Distance)
            .Take(maxResults)
            .ToList();

        // 查询成员数并构建响应
        var circleIds = topResults.Select(r => r.Circle.Id).ToList();
        var memberCounts = await _context.NeighborCircleMembers
            .Where(m => circleIds.Contains(m.CircleId))
            .GroupBy(m => m.CircleId)
            .Select(g => new { CircleId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.CircleId, x => x.Count, cancellationToken);

        return topResults.Select(r => new NeighborCircleResponse
        {
            Id = r.Circle.Id,
            CircleName = r.Circle.CircleName,
            CenterLatitude = r.Circle.CenterLatitude,
            CenterLongitude = r.Circle.CenterLongitude,
            RadiusMeters = r.Circle.RadiusMeters,
            CreatorId = r.Circle.CreatorId,
            InviteCode = string.Empty, // 搜索结果不暴露邀请码
            InviteCodeExpiresAt = null,
            MemberCount = memberCounts.GetValueOrDefault(r.Circle.Id),
            IsActive = r.Circle.IsActive,
            CreatedAt = r.Circle.CreatedAt,
            DistanceMeters = r.Distance
        }).ToList();
    }

    /// <inheritdoc />
    public async Task<NeighborCircleResponse> RefreshInviteCodeAsync(Guid circleId, Guid operatorId, CancellationToken cancellationToken = default)
    {
        await EnsureCircleMemberAsync(circleId, operatorId, cancellationToken);

        var circle = await _context.NeighborCircles
            .AsTracking()
            .FirstOrDefaultAsync(c => c.Id == circleId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborCircle.CircleNotFound);

        if (circle.CreatorId != operatorId)
            throw new UnauthorizedAccessException(ErrorMessages.NeighborCircle.OnlyCreatorCanRefreshCode);

        circle.InviteCode = GenerateInviteCode();
        circle.InviteCodeExpiresAt = DateTime.UtcNow.Add(_inviteCodeExpiration);

        // 唯一约束冲突时自动重试生成新邀请码（6位数字碰撞概率极低，最多重试3次）
        for (var attempt = 0; attempt < 3; attempt++)
        {
            try
            {
                await _context.SaveChangesAsync(cancellationToken);
                break;
            }
            catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex) && attempt < 2)
            {
                circle.InviteCode = GenerateInviteCode();
            }
        }

        return await BuildCircleResponse(circleId, cancellationToken);
    }

    /// <inheritdoc />
    public async Task EnsureCircleMemberAsync(Guid circleId, Guid userId, CancellationToken cancellationToken = default)
    {
        if (!await _context.NeighborCircleMembers
                .AnyAsync(m => m.CircleId == circleId && m.UserId == userId, cancellationToken))
            throw new UnauthorizedAccessException(ErrorMessages.NeighborCircle.NotCircleMember);
    }

    /// <summary>
    /// 使用加密随机数生成器生成 6 位数字邀请码，防止可预测攻击
    /// </summary>
    private static string GenerateInviteCode() => InviteCodeHelper.Generate();

    /// <summary>
    /// 构建邻里圈响应（含创建者名称和成员数），使用投影减少数据库交互
    /// </summary>
    private async Task<NeighborCircleResponse> BuildCircleResponse(Guid circleId, CancellationToken cancellationToken = default)
    {
        return await _context.NeighborCircles
            .Where(c => c.Id == circleId)
            .Select(c => new NeighborCircleResponse
            {
                Id = c.Id,
                CircleName = c.CircleName,
                CenterLatitude = c.CenterLatitude,
                CenterLongitude = c.CenterLongitude,
                RadiusMeters = c.RadiusMeters,
                CreatorId = c.CreatorId,
                CreatorName = c.Creator != null ? c.Creator.RealName : string.Empty,
                InviteCode = c.InviteCode,
                InviteCodeExpiresAt = c.InviteCodeExpiresAt,
                MemberCount = _context.NeighborCircleMembers.Count(m => m.CircleId == circleId),
                IsActive = c.IsActive,
                CreatedAt = c.CreatedAt
            })
            .FirstAsync(cancellationToken);
    }
}
