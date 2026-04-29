using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 位置服务实现
/// </summary>
public class LocationService : ILocationService
{
    private readonly AppDbContext _context;
    private readonly IGeoFenceService _geoFenceService;
    private readonly INotificationService _notificationService;
    private readonly IAutoRescueService _autoRescueService;
    private readonly ILogger<LocationService> _logger;
    private readonly double _accuracyThreshold;

    public LocationService(
        AppDbContext context,
        IGeoFenceService geoFenceService,
        INotificationService notificationService,
        IAutoRescueService autoRescueService,
        ILogger<LocationService> logger,
        IConfiguration? configuration = null)
    {
        _accuracyThreshold = configuration?.GetValue(ConfigurationKeys.Location.AccuracyThresholdMeters, AppConstants.Location.DefaultAccuracyThresholdMeters) ?? AppConstants.Location.DefaultAccuracyThresholdMeters;
        _context = context;
        _geoFenceService = geoFenceService;
        _notificationService = notificationService;
        _autoRescueService = autoRescueService;
        _logger = logger;
    }

    /// <summary>
    /// 上报位置
    /// </summary>
    public async Task<LocationRecordResponse> ReportLocationAsync(Guid userId, double latitude, double longitude, double? accuracy = null, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users.FindAsync(new object[] { userId }, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        var record = new LocationRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Latitude = latitude,
            Longitude = longitude,
            RecordedAt = DateTime.UtcNow,
        };

        _context.LocationRecords.Add(record);
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogDebug("用户 {UserId} 位置已记录: ({Lat:F4}, {Lng:F4})", userId, latitude, longitude);

        // GPS 精度过滤：精度超过阈值时跳过围栏检查，防止室内飘移误报
        var shouldCheckFence = accuracy == null || accuracy.Value <= _accuracyThreshold;

        if (!shouldCheckFence)
        {
            _logger.LogDebug("[位置上报] GPS 精度 {Accuracy:F0}m 超过阈值 {Threshold}m，跳过围栏检查",
                accuracy, _accuracyThreshold);
        }

        // 检查是否超出电子围栏
        if (shouldCheckFence)
        {
            var outsideResult = await _geoFenceService.CheckOutsideFenceAsync(userId, latitude, longitude, cancellationToken);
            if (outsideResult != null)
            {
                var (fence, distance) = outsideResult.Value;
                _logger.LogWarning("老人 {UserId} 已超出电子围栏 {FenceId}，距离 {Distance:F0}m", userId, fence!.Id, distance);
                HangfireJobHelper.EnqueueSafely(
                    () => SendGeoFenceAlertJobAsync(userId, fence!.Id, fence.Radius, distance),
                    "围栏预警", _logger, userId);
            }
        }

        return new LocationRecordResponse
        {
            Id = record.Id,
            UserId = record.UserId,
            RealName = user.RealName,
            Latitude = record.Latitude,
            Longitude = record.Longitude,
            RecordedAt = record.RecordedAt,
        };
    }

    /// <summary>
    /// 获取用户最新位置
    /// </summary>
    public async Task<LocationRecordResponse?> GetLatestLocationAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var record = await _context.LocationRecords
            .Include(r => r.User)
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.RecordedAt)
            .FirstOrDefaultAsync(cancellationToken);

        if (record == null) return null;

        return MapToResponse(record);
    }

    /// <summary>
    /// 获取用户位置历史
    /// </summary>
    public async Task<List<LocationRecordResponse>> GetLocationHistoryAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default)
    {
        var records = await _context.LocationRecords
            .Include(r => r.User)
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.RecordedAt)
            .Skip(skip)
            .Take(limit)
            .ToListAsync(cancellationToken);

        return records.Select(MapToResponse).ToList();
    }

    /// <summary>
    /// 获取家庭成员最新位置（子女查看老人）
    /// </summary>
    public async Task<LocationRecordResponse?> GetFamilyMemberLatestLocationAsync(Guid familyId, Guid memberId, CancellationToken cancellationToken = default)
    {
        // 验证 memberId 是否在该家庭中
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId, cancellationToken);

        if (!isMember) return null;

        return await GetLatestLocationAsync(memberId, cancellationToken);
    }

    /// <summary>
    /// 获取家庭成员位置历史（子女查看老人）
    /// </summary>
    public async Task<List<LocationRecordResponse>> GetFamilyMemberLocationHistoryAsync(Guid familyId, Guid memberId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default)
    {
        // 验证 memberId 是否在该家庭中
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId, cancellationToken);

        if (!isMember) return [];

        return await GetLocationHistoryAsync(memberId, skip, limit, cancellationToken);
    }

    /// <summary>
    /// Hangfire 后台任务：发送电子围栏超出预警通知
    /// 通过 fenceId 重新获取围栏数据，避免序列化复杂对象
    /// </summary>
    public async Task SendGeoFenceAlertJobAsync(Guid elderId, Guid fenceId, int fenceRadius, double distance)
    {
        try
        {
            await SendGeoFenceAlertAsync(elderId, fenceId, fenceRadius, distance);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "围栏预警通知发送失败，用户 {UserId}", elderId);
        }
    }

    /// <summary>
    /// 发送电子围栏超出预警通知给子女
    /// </summary>
    private async Task SendGeoFenceAlertAsync(Guid elderId, Guid fenceId, int fenceRadius, double distance, CancellationToken cancellationToken = default)
    {
        // 一次查询获取老人所在家庭的所有成员（含子女），减少数据库往返
        var familyMembers = await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.FamilyId == _context.FamilyMembers
                .Where(efm => efm.UserId == elderId)
                .Select(efm => efm.FamilyId)
                .First())
            .ToListAsync(cancellationToken);

        var familyMember = familyMembers.FirstOrDefault(fm => fm.UserId == elderId);
        if (familyMember == null) return;

        var elderName = familyMember.User?.RealName ?? AppConstants.HealthTypeLabels.DefaultElderName;
        var children = familyMembers.Where(fm => fm.Role == UserRole.Child).ToList();
        if (!children.Any()) return;

        // 构建通知内容
        var distanceText = distance > AppConstants.Location.DistanceDisplayThresholdMeters
            ? $"{(distance / AppConstants.Location.DistanceDisplayThresholdMeters):.1}{AppConstants.Location.KilometerUnit}"
            : $"{(int)distance}{AppConstants.Location.MeterUnit}";

        await _notificationService.SendToUsersAsync(
            children.Select(c => c.UserId),
            AppConstants.NotificationTypes.GeoFenceAlert,
            new
            {
                Title = NotificationMessages.Location.GeoFenceAlertTitle,
                Content = string.Format(NotificationMessages.Location.GeoFenceAlertContentTemplate, elderName, distanceText),
                ElderId = elderId,
                ElderName = elderName,
                FenceId = fenceId,
                FenceRadius = fenceRadius,
                Distance = distance,
                AlertLevel = distance > fenceRadius * 2 ? AppConstants.AlertLevels.Critical : AppConstants.AlertLevels.Warning
            },
            cancellationToken
        );

        // 检查老人是否在邻里圈中，若在则启动自动救援计时器
        var circleMembership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == elderId, cancellationToken);
        if (circleMembership != null)
        {
            try
            {
                await _autoRescueService.StartRescueTimerAsync(
                    elderId, familyMember.FamilyId, circleMembership.CircleId,
                    RescueTriggerType.GeoFenceBreach);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "启动自动救援计时器失败，老人 {ElderId}", elderId);
            }
        }
    }

    /// <summary>
    /// 将 LocationRecord 实体映射为响应 DTO
    /// </summary>
    private static LocationRecordResponse MapToResponse(LocationRecord r) => new()
    {
        Id = r.Id,
        UserId = r.UserId,
        RealName = r.User?.RealName ?? string.Empty,
        Latitude = r.Latitude,
        Longitude = r.Longitude,
        RecordedAt = r.RecordedAt,
    };
}