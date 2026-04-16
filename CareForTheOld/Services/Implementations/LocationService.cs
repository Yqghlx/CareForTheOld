using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 位置服务实现
/// </summary>
public class LocationService : ILocationService
{
    private readonly AppDbContext _context;
    private readonly IGeoFenceService _geoFenceService;
    private readonly INotificationService _notificationService;

    public LocationService(
        AppDbContext context,
        IGeoFenceService geoFenceService,
        INotificationService notificationService)
    {
        _context = context;
        _geoFenceService = geoFenceService;
        _notificationService = notificationService;
    }

    /// <summary>
    /// 上报位置
    /// </summary>
    public async Task<LocationRecordResponse> ReportLocationAsync(Guid userId, double latitude, double longitude)
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

        // 检查是否超出电子围栏
        var outsideResult = await _geoFenceService.CheckOutsideFenceAsync(userId, latitude, longitude);
        if (outsideResult != null)
        {
            var (fence, distance) = outsideResult.Value;
            // 异步发送围栏预警通知，不阻塞主流程
            _ = SendGeoFenceAlertAsync(userId, fence!, distance);
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
    public async Task<List<LocationRecordResponse>> GetLocationHistoryAsync(Guid userId, int limit = 50)
    {
        var records = await _context.LocationRecords
            .Include(r => r.User)
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.RecordedAt)
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
    public async Task<List<LocationRecordResponse>> GetFamilyMemberLocationHistoryAsync(Guid familyId, Guid memberId, int limit = 50)
    {
        // 验证 memberId 是否在该家庭中
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId);

        if (!isMember) return [];

        return await GetLocationHistoryAsync(memberId, limit);
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

        foreach (var child in children)
        {
            await _notificationService.SendToUserAsync(
                child.UserId,
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