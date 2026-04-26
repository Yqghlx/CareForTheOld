using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Hangfire;
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
        _accuracyThreshold = configuration?.GetValue("Location:AccuracyThresholdMeters", AppConstants.Location.DefaultAccuracyThresholdMeters) ?? AppConstants.Location.DefaultAccuracyThresholdMeters;
        _context = context;
        _geoFenceService = geoFenceService;
        _notificationService = notificationService;
        _autoRescueService = autoRescueService;
        _logger = logger;
    }

    /// <summary>
    /// 上报位置
    /// </summary>
    public async Task<LocationRecordResponse> ReportLocationAsync(Guid userId, double latitude, double longitude, double? accuracy = null)
    {
        var user = await _context.Users.FindAsync(userId)
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
        await _context.SaveChangesAsync();

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
            var outsideResult = await _geoFenceService.CheckOutsideFenceAsync(userId, latitude, longitude);
            if (outsideResult != null)
            {
                var (fence, distance) = outsideResult.Value;
                // 通过 Hangfire 异步发送围栏预警通知，支持持久化和自动重试
                BackgroundJob.Enqueue(() => SendGeoFenceAlertJobAsync(
                    userId, fence!.Id, fence.Radius, distance));
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
    public async Task<LocationRecordResponse?> GetLatestLocationAsync(Guid userId)
    {
        var record = await _context.LocationRecords
            .Include(r => r.User)
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.RecordedAt)
            .FirstOrDefaultAsync();

        if (record == null) return null;

        return new LocationRecordResponse
        {
            Id = record.Id,
            UserId = record.UserId,
            RealName = record.User.RealName,
            Latitude = record.Latitude,
            Longitude = record.Longitude,
            RecordedAt = record.RecordedAt,
        };
    }

    /// <summary>
    /// 获取用户位置历史
    /// </summary>
    public async Task<List<LocationRecordResponse>> GetLocationHistoryAsync(Guid userId, int skip = 0, int limit = 50)
    {
        var records = await _context.LocationRecords
            .Include(r => r.User)
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.RecordedAt)
            .Skip(skip)
            .Take(limit)
            .ToListAsync();

        return records.Select(r => new LocationRecordResponse
        {
            Id = r.Id,
            UserId = r.UserId,
            RealName = r.User.RealName,
            Latitude = r.Latitude,
            Longitude = r.Longitude,
            RecordedAt = r.RecordedAt,
        }).ToList();
    }

    /// <summary>
    /// 获取家庭成员最新位置（子女查看老人）
    /// </summary>
    public async Task<LocationRecordResponse?> GetFamilyMemberLatestLocationAsync(Guid familyId, Guid memberId)
    {
        // 验证 memberId 是否在该家庭中
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId);

        if (!isMember) return null;

        return await GetLatestLocationAsync(memberId);
    }

    /// <summary>
    /// 获取家庭成员位置历史（子女查看老人）
    /// </summary>
    public async Task<List<LocationRecordResponse>> GetFamilyMemberLocationHistoryAsync(Guid familyId, Guid memberId, int skip = 0, int limit = 50)
    {
        // 验证 memberId 是否在该家庭中
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId);

        if (!isMember) return [];

        return await GetLocationHistoryAsync(memberId, skip, limit);
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
    private async Task SendGeoFenceAlertAsync(Guid elderId, Guid fenceId, int fenceRadius, double distance)
    {
        // 获取老人所在的家庭
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == elderId);

        if (familyMember == null) return; // 老人没有加入家庭，无法通知

        // 获取老人姓名
        var elder = await _context.Users.FindAsync(elderId);
        var elderName = elder?.RealName ?? "老人";

        // 获取家庭中的子女成员
        var children = await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.FamilyId == familyMember.FamilyId && fm.Role == UserRole.Child)
            .ToListAsync();

        if (children.Count == 0) return; // 没有子女成员

        // 构建通知内容
        var distanceText = distance > 1000
            ? $"{(distance / 1000):.1}公里"
            : $"{(int)distance}米";

        await _notificationService.SendToUsersAsync(
            children.Select(c => c.UserId),
            AppConstants.NotificationTypes.GeoFenceAlert,
            new
            {
                Title = NotificationMessages.Location.GeoFenceAlertTitle,
                Content = $"{elderName}已离开安全区域，当前位置距离安全中心{distanceText}，请及时关注。",
                ElderId = elderId,
                ElderName = elderName,
                FenceId = fenceId,
                FenceRadius = fenceRadius,
                Distance = distance,
                AlertLevel = distance > fenceRadius * 2 ? AppConstants.AlertLevels.Critical : AppConstants.AlertLevels.Warning
            }
        );

        // 检查老人是否在邻里圈中，若在则启动自动救援计时器
        var circleMembership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == elderId);
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
}