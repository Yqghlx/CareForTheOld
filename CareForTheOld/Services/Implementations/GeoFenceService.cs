using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.GeoFences;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 电子围栏服务实现
///
/// 围栏数据通过 Redis 缓存热点化，位置上报时直接从缓存读取围栏，
/// 避免每次位置校验都查询数据库，将围栏查询响应时间降低一个数量级。
/// 写操作（创建/更新/删除）后自动刷新缓存。
/// </summary>
public class GeoFenceService : IGeoFenceService
{
    private readonly AppDbContext _context;
    private readonly ICacheService _cacheService;
    private readonly IFamilyService _familyService;
    private readonly ILogger<GeoFenceService> _logger;

    /// <summary>
    /// 围栏缓存 key 前缀（格式：geofence:{elderId}）
    /// </summary>
    private const string _cacheKeyPrefix = AppConstants.Cache.GeoFencePrefix;

    /// <summary>
    /// 围栏缓存过期时间，使用 AppConstants.Cache.GeoFenceExpirationMinutes 统一管理
    /// </summary>
    private static readonly TimeSpan _cacheExpiration = TimeSpan.FromMinutes(AppConstants.Cache.GeoFenceExpirationMinutes);

    public GeoFenceService(AppDbContext context, ICacheService cacheService, IFamilyService familyService, ILogger<GeoFenceService> logger)
    {
        _context = context;
        _cacheService = cacheService;
        _familyService = familyService;
        _logger = logger;
    }

    /// <summary>
    /// 创建电子围栏（需验证是否为老人的家庭成员）
    /// </summary>
    public async Task<GeoFenceResponse> CreateFenceAsync(Guid creatorId, CreateGeoFenceRequest request, CancellationToken cancellationToken = default)
    {
        // 验证创建者是否是老人的家庭成员
        await _familyService.EnsureFamilyMemberAsync(request.ElderId, creatorId, cancellationToken);

        // 检查老人是否已存在围栏（一个老人只能有一个围栏）
        var existingFence = await _context.GeoFences
            .AsTracking()
            .FirstOrDefaultAsync(f => f.ElderId == request.ElderId, cancellationToken);

        if (existingFence != null)
        {
            // 更新现有围栏
            existingFence.CenterLatitude = request.CenterLatitude;
            existingFence.CenterLongitude = request.CenterLongitude;
            existingFence.Radius = request.Radius;
            existingFence.IsEnabled = request.IsEnabled;
            existingFence.CreatedBy = creatorId;
            existingFence.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);
            await InvalidateCacheAsync(request.ElderId);
            _logger.LogInformation("电子围栏已更新：老人 {ElderId}，操作者 {OperatorId}", request.ElderId, creatorId);
            return MapToResponse(existingFence);
        }

        // 创建新围栏
        var fence = new GeoFence
        {
            Id = Guid.NewGuid(),
            ElderId = request.ElderId,
            CenterLatitude = request.CenterLatitude,
            CenterLongitude = request.CenterLongitude,
            Radius = request.Radius,
            IsEnabled = request.IsEnabled,
            CreatedBy = creatorId,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.GeoFences.Add(fence);

        try
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            // 并发创建同一老人围栏时的唯一约束冲突，重新查询已创建的围栏返回
            _logger.LogWarning("电子围栏并发创建冲突，老人 {ElderId}，回查已有围栏", request.ElderId);
            var existing = await _context.GeoFences.FirstOrDefaultAsync(f => f.ElderId == request.ElderId, cancellationToken);
            if (existing != null)
            {
                await InvalidateCacheAsync(request.ElderId);
                return MapToResponse(existing);
            }
            throw;
        }

        await InvalidateCacheAsync(request.ElderId);
        _logger.LogInformation("电子围栏已创建：老人 {ElderId}，操作者 {OperatorId}，半径 {Radius}m", request.ElderId, creatorId, request.Radius);

        return MapToResponse(fence);
    }

    /// <summary>
    /// 获取老人的电子围栏
    /// </summary>
    public async Task<GeoFenceResponse?> GetElderFenceAsync(Guid elderId, CancellationToken cancellationToken = default)
    {
        var fence = await _context.GeoFences
            .Include(f => f.Elder)
            .FirstOrDefaultAsync(f => f.ElderId == elderId, cancellationToken);

        return fence == null ? null : MapToResponse(fence);
    }

    /// <summary>
    /// 更新电子围栏
    /// </summary>
    public async Task<GeoFenceResponse> UpdateFenceAsync(Guid fenceId, Guid operatorId, CreateGeoFenceRequest request, CancellationToken cancellationToken = default)
    {
        var fence = await _context.GeoFences
            .AsTracking()
            .Include(f => f.Elder)
            .FirstOrDefaultAsync(f => f.Id == fenceId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.GeoFence.NotFound);

        // 验证操作者是否是创建者或家庭成员
        var isFamilyMember = await IsInSameFamilyAsync(operatorId, fence.ElderId, cancellationToken);

        if (fence.CreatedBy != operatorId && !isFamilyMember)
            throw new UnauthorizedAccessException(ErrorMessages.GeoFence.NoPermissionToEdit);

        fence.CenterLatitude = request.CenterLatitude;
        fence.CenterLongitude = request.CenterLongitude;
        fence.Radius = request.Radius;
        fence.IsEnabled = request.IsEnabled;
        fence.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);
        await InvalidateCacheAsync(fence.ElderId);
        _logger.LogInformation("电子围栏已更新：围栏 {FenceId}，操作者 {OperatorId}", fenceId, operatorId);

        return MapToResponse(fence);
    }

    /// <summary>
    /// 删除电子围栏
    /// </summary>
    public async Task DeleteFenceAsync(Guid fenceId, Guid operatorId, CancellationToken cancellationToken = default)
    {
        var fence = await _context.GeoFences
            .AsTracking()
            .FirstOrDefaultAsync(f => f.Id == fenceId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.GeoFence.NotFound);

        // 验证操作者是否是创建者或家庭成员
        var isFamilyMember = await IsInSameFamilyAsync(operatorId, fence.ElderId, cancellationToken);

        if (fence.CreatedBy != operatorId && !isFamilyMember)
            throw new UnauthorizedAccessException(ErrorMessages.GeoFence.NoPermissionToDelete);

        _context.GeoFences.Remove(fence);
        await _context.SaveChangesAsync(cancellationToken);
        await InvalidateCacheAsync(fence.ElderId);
        _logger.LogInformation("电子围栏已删除：围栏 {FenceId}，老人 {ElderId}，操作者 {OperatorId}", fenceId, fence.ElderId, operatorId);
    }

    /// <summary>
    /// 检查用户是否超出围栏（优先从 Redis 缓存读取围栏数据）
    ///
    /// 位置上报是高频操作（每 5 分钟一次），围栏数据变更频率极低。
    /// 将围栏数据缓存至 Redis 后，位置校验无需查询数据库，响应时间降低一个数量级。
    /// </summary>
    public async Task<(GeoFenceResponse? fence, double distance)?> CheckOutsideFenceAsync(Guid userId, double latitude, double longitude, CancellationToken cancellationToken = default)
    {
        var cacheKey = $"{_cacheKeyPrefix}{userId}";

        // 优先从缓存获取围栏数据
        var cachedFence = await _cacheService.GetOrCreateAsync<GeoFenceCacheEntry>(
            cacheKey,
            async () =>
            {
                // 缓存未命中：从数据库加载
                var fence = await _context.GeoFences
                    .Include(f => f.Elder)
                    .FirstOrDefaultAsync(f => f.ElderId == userId && f.IsEnabled, cancellationToken);

                if (fence == null) return null;

                return new GeoFenceCacheEntry
                {
                    Id = fence.Id,
                    ElderId = fence.ElderId,
                    ElderName = fence.Elder?.RealName ?? "",
                    CenterLatitude = fence.CenterLatitude,
                    CenterLongitude = fence.CenterLongitude,
                    Radius = fence.Radius,
                    IsEnabled = fence.IsEnabled,
                    CreatedBy = fence.CreatedBy,
                    CreatedAt = fence.CreatedAt,
                    UpdatedAt = fence.UpdatedAt
                };
            },
            _cacheExpiration);

        if (cachedFence == null) return null;

        // 计算当前位置与围栏中心的距离
        var distance = GeoHelper.HaversineDistance(latitude, longitude, cachedFence.CenterLatitude, cachedFence.CenterLongitude);

        // 超出围栏
        if (distance > cachedFence.Radius)
        {
            return (MapToResponse(cachedFence), distance);
        }

        return null;
    }


    /// <summary>
    /// 从缓存条目映射到响应对象
    /// </summary>
    private static GeoFenceResponse MapToResponse(GeoFenceCacheEntry cached)
        => new()
        {
            Id = cached.Id,
            ElderId = cached.ElderId,
            ElderName = cached.ElderName,
            CenterLatitude = cached.CenterLatitude,
            CenterLongitude = cached.CenterLongitude,
            Radius = (int)cached.Radius,
            IsEnabled = cached.IsEnabled,
            CreatedBy = cached.CreatedBy,
            CreatedAt = cached.CreatedAt,
            UpdatedAt = cached.UpdatedAt
        };

    /// <summary>
    /// 从数据库实体映射到响应对象
    /// </summary>
    private static GeoFenceResponse MapToResponse(GeoFence fence)
    {
        return new GeoFenceResponse
        {
            Id = fence.Id,
            ElderId = fence.ElderId,
            ElderName = fence.Elder?.RealName,
            CenterLatitude = fence.CenterLatitude,
            CenterLongitude = fence.CenterLongitude,
            Radius = fence.Radius,
            IsEnabled = fence.IsEnabled,
            CreatedBy = fence.CreatedBy,
            CreatedAt = fence.CreatedAt,
            UpdatedAt = fence.UpdatedAt
        };
    }

    /// <summary>
    /// 检查两个用户是否在同一家庭（使用 JOIN 单次查询）
    /// </summary>
    private async Task<bool> IsInSameFamilyAsync(Guid userId1, Guid userId2, CancellationToken cancellationToken = default)
    {
        return await _context.FamilyMembers
            .Where(fm1 => fm1.UserId == userId1)
            .AnyAsync(fm1 => _context.FamilyMembers
                .Any(fm2 => fm2.UserId == userId2 && fm2.FamilyId == fm1.FamilyId), cancellationToken);
    }

    /// <summary>
    /// 清除指定老人的围栏缓存（写操作后调用）
    /// </summary>
    private async Task InvalidateCacheAsync(Guid elderId)
    {
        await _cacheService.RemoveAsync($"{_cacheKeyPrefix}{elderId}");
    }
}

/// <summary>
/// 围栏缓存条目（轻量级 DTO，仅包含围栏校验所需的核心字段）
///
/// 不直接缓存 GeoFence 实体，避免 EF Core 导航属性序列化问题，
/// 同时减少缓存体积，提升 Redis 读写效率。
/// </summary>
public class GeoFenceCacheEntry
{
    public Guid Id { get; set; }
    public Guid ElderId { get; set; }
    public string ElderName { get; set; } = string.Empty;
    public double CenterLatitude { get; set; }
    public double CenterLongitude { get; set; }
    public double Radius { get; set; }
    public bool IsEnabled { get; set; }
    public Guid CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
