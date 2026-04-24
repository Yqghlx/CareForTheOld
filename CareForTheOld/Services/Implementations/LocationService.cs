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
    private readonly ILogger<LocationService> _logger;
    private readonly double _accuracyThreshold;

    public LocationService(
        AppDbContext context,
        IGeoFenceService geoFenceService,
        INotificationService notificationService,
        ILogger<LocationService> logger,
        IConfiguration? configuration = null)
    {
        _accuracyThreshold = configuration?.GetValue("Location:AccuracyThresholdMeters", 100.0) ?? 100.0;
        _context = context;
        _geoFenceService = geoFenceService;
        _notificationService = notificationService;
        _logger = logger;
    }

    /// <summary>
    /// 上报位置
    /// </summary>
    public async Task<LocationRecordResponse> ReportLocationAsync(Guid userId, double latitude, double longitude, double? accuracy = null)
    {
        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("用户不存在");

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
                // 异步发送围栏预警通知，不阻塞主流程，捕获异常防止后台任务崩溃
                _ = Task.Run(async () =>
                {
                    try
                    {
                        await SendGeoFenceAlertAsync(userId, fence!, distance);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "围栏预警通知发送失败，用户 {UserId}", userId);
                    }
                });
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
    /// 发送电子围栏超出预警通知给子女
    /// </summary>
    private async Task SendGeoFenceAlertAsync(Guid elderId, GeoFenceResponse fence, double distance)
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

        if (children.Count > 0)
        {
            await _notificationService.SendToUsersAsync(
                children.Select(c => c.UserId),
                "GeoFenceAlert",
                new
                {
                    Title = "安全区域预警",
                    Content = $"{elderName}已离开安全区域，当前位置距离安全中心{distanceText}，请及时关注。",
                    ElderId = elderId,
                    ElderName = elderName,
                    FenceId = fence.Id,
                    FenceRadius = fence.Radius,
                    Distance = distance,
                    AlertLevel = distance > fence.Radius * 2 ? "Critical" : "Warning"
                }
            );
        }
    }
}