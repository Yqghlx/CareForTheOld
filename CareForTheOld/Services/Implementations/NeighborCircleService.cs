using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 邻里圈服务实现
/// </summary>
public class NeighborCircleService : INeighborCircleService
{
    private readonly AppDbContext _context;

    /// <summary>邀请码有效期</summary>
    private static readonly TimeSpan _inviteCodeExpiration = TimeSpan.FromDays(AppConstants.InviteCode.ExpirationDays);

    public NeighborCircleService(AppDbContext context) => _context = context;

    /// <inheritdoc />
    public async Task<NeighborCircleResponse> CreateCircleAsync(Guid creatorId, CreateNeighborCircleRequest request)
    {
        // 一个用户同一时间只能加入一个邻里圈
        if (await _context.NeighborCircleMembers.AnyAsync(m => m.UserId == creatorId))
            throw new ArgumentException(ErrorMessages.NeighborCircle.AlreadyInCircleCreate);

        var creator = await _context.Users.FindAsync(creatorId)
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
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.NeighborCircle.AlreadyInCircleCreate);
        }

        return await BuildCircleResponse(circle.Id);
    }

    /// <inheritdoc />
    public async Task<NeighborCircleResponse?> GetMyCircleAsync(Guid userId)
    {
        var membership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == userId);

        if (membership == null)
            return null;

        return await BuildCircleResponse(membership.CircleId);
    }

    /// <inheritdoc />
    public async Task<NeighborCircleResponse> GetCircleAsync(Guid circleId)
    {
        return await BuildCircleResponse(circleId);
    }

    /// <inheritdoc />
    public async Task<NeighborCircleResponse> JoinCircleByCodeAsync(Guid userId, JoinNeighborCircleRequest request)
    {
        // 检查用户是否已在某个圈子中
        if (await _context.NeighborCircleMembers.AnyAsync(m => m.UserId == userId))
            throw new ArgumentException(ErrorMessages.NeighborCircle.AlreadyInCircleJoin);

        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 根据邀请码查找活跃的圈子
        var circle = await _context.NeighborCircles
            .FirstOrDefaultAsync(c => c.InviteCode == request.InviteCode && c.IsActive)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborCircle.InvalidInviteCode);

        // 验证邀请码是否过期
        if (circle.InviteCodeExpiresAt.HasValue && circle.InviteCodeExpiresAt.Value < DateTime.UtcNow)
            throw new ArgumentException(ErrorMessages.NeighborCircle.InviteCodeExpired);

        // 检查成员上限
        var memberCount = await _context.NeighborCircleMembers
            .CountAsync(m => m.CircleId == circle.Id);

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
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.NeighborCircle.AlreadyInCircleJoin);
        }

        return await BuildCircleResponse(circle.Id);
    }

    /// <inheritdoc />
    public async Task LeaveCircleAsync(Guid circleId, Guid userId)
    {
        var circle = await _context.NeighborCircles
            .Include(c => c.Members)
            .FirstOrDefaultAsync(c => c.Id == circleId)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborCircle.CircleNotFound);

        var member = circle.Members.FirstOrDefault(m => m.UserId == userId)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborCircle.NotCircleMember);

        if (circle.CreatorId == userId)
        {
            // 创建者退出 → 解散整个圈子
            circle.IsActive = false;
            _context.NeighborCircleMembers.RemoveRange(circle.Members);

            // 必须用 AsTracking 才能在 NoTracking 全局模式下更新
            var trackedCircle = await _context.NeighborCircles
                .AsTracking()
                .FirstAsync(c => c.Id == circleId);
            trackedCircle.IsActive = false;
        }
        else
        {
            _context.NeighborCircleMembers.Remove(member);
        }

        await _context.SaveChangesAsync();
    }

    /// <inheritdoc />
    public async Task<List<NeighborMemberResponse>> GetMembersAsync(Guid circleId)
    {
        return await _context.NeighborCircleMembers
            .Include(m => m.User)
            .Where(m => m.CircleId == circleId)
            .Select(m => new NeighborMemberResponse
            {
                UserId = m.UserId,
                RealName = m.User.RealName,
                Role = m.Role,
                Nickname = m.Nickname,
                AvatarUrl = m.User.AvatarUrl,
                JoinedAt = m.JoinedAt
            })
            .ToListAsync();
    }

    /// <inheritdoc />
    public async Task<List<NeighborMemberResponse>> GetNearbyMembersAsync(
        Guid circleId, double latitude, double longitude, double radiusMeters = AppConstants.NeighborCircle.DefaultMemberRadiusMeters)
    {
        // 先获取圈子所有成员，再用最近位置记录计算距离
        var memberIds = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == circleId)
            .Select(m => m.UserId)
            .ToListAsync();

        // 获取每个成员最近的位置记录
        var recentLocations = await _context.LocationRecords
            .GroupBy(l => l.UserId)
            .Where(g => memberIds.Contains(g.Key))
            .Select(g => g.OrderByDescending(l => l.RecordedAt).First())
            .ToListAsync();

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

        if (nearbyUserIds.Count == 0)
            return [];

        // 查询成员详情并附加距离
        var members = await _context.NeighborCircleMembers
            .Include(m => m.User)
            .Where(m => m.CircleId == circleId && nearbyUserIds.Contains(m.UserId))
            .Select(m => new NeighborMemberResponse
            {
                UserId = m.UserId,
                RealName = m.User.RealName,
                Role = m.Role,
                Nickname = m.Nickname,
                AvatarUrl = m.User.AvatarUrl,
                JoinedAt = m.JoinedAt
            })
            .ToListAsync();

        // 附加距离信息
        foreach (var m in members)
        {
            m.DistanceMeters = distanceMap[m.UserId];
        }
        return members;
    }

    /// <inheritdoc />
    public async Task<List<NeighborCircleResponse>> SearchNearbyCirclesAsync(
        double latitude, double longitude, double radiusMeters = AppConstants.NeighborCircle.SearchRadiusMeters, int maxResults = AppConstants.NeighborCircle.SearchMaxResults)
    {
        // 只搜索活跃的圈子
        var circles = await _context.NeighborCircles
            .Where(c => c.IsActive)
            .ToListAsync();

        // 经纬度粗筛阈值
        var (latThreshold, _) = GeoHelper.CalculateDegreeThresholds(radiusMeters, latitude);

        var results = new List<(NeighborCircle Circle, double Distance)>();

        foreach (var circle in circles)
        {
            // 粗筛：搜索点到圈子中心距离不超过（搜索半径 + 圈子半径）
            var (extendedLatThreshold, extendedLngThreshold) = GeoHelper.CalculateDegreeThresholds(radiusMeters + circle.RadiusMeters, latitude);

            if (Math.Abs(circle.CenterLatitude - latitude) > extendedLatThreshold ||
                Math.Abs(circle.CenterLongitude - longitude) > extendedLngThreshold)
                continue;

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
            .ToDictionaryAsync(x => x.CircleId, x => x.Count);

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
    public async Task<NeighborCircleResponse> RefreshInviteCodeAsync(Guid circleId, Guid operatorId)
    {
        await EnsureCircleMemberAsync(circleId, operatorId);

        var circle = await _context.NeighborCircles
            .AsTracking()
            .FirstOrDefaultAsync(c => c.Id == circleId)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborCircle.CircleNotFound);

        if (circle.CreatorId != operatorId)
            throw new UnauthorizedAccessException(ErrorMessages.NeighborCircle.OnlyCreatorCanRefreshCode);

        circle.InviteCode = GenerateInviteCode();
        circle.InviteCodeExpiresAt = DateTime.UtcNow.Add(_inviteCodeExpiration);
        await _context.SaveChangesAsync();

        return await BuildCircleResponse(circleId);
    }

    /// <inheritdoc />
    public async Task EnsureCircleMemberAsync(Guid circleId, Guid userId)
    {
        if (!await _context.NeighborCircleMembers
                .AnyAsync(m => m.CircleId == circleId && m.UserId == userId))
            throw new UnauthorizedAccessException(ErrorMessages.NeighborCircle.NotCircleMember);
    }

    /// <summary>
    /// 使用加密随机数生成器生成 6 位数字邀请码，防止可预测攻击
    /// </summary>
    private static string GenerateInviteCode() => InviteCodeHelper.Generate();

    /// <summary>
    /// 构建邻里圈响应（含创建者名称和成员数）
    /// </summary>
    private async Task<NeighborCircleResponse> BuildCircleResponse(Guid circleId)
    {
        var circle = await _context.NeighborCircles
            .Include(c => c.Creator)
            .FirstAsync(c => c.Id == circleId);

        var memberCount = await _context.NeighborCircleMembers
            .CountAsync(m => m.CircleId == circleId);

        return new NeighborCircleResponse
        {
            Id = circle.Id,
            CircleName = circle.CircleName,
            CenterLatitude = circle.CenterLatitude,
            CenterLongitude = circle.CenterLongitude,
            RadiusMeters = circle.RadiusMeters,
            CreatorId = circle.CreatorId,
            CreatorName = circle.Creator.RealName,
            InviteCode = circle.InviteCode,
            InviteCodeExpiresAt = circle.InviteCodeExpiresAt,
            MemberCount = memberCount,
            IsActive = circle.IsActive,
            CreatedAt = circle.CreatedAt
        };
    }
}
