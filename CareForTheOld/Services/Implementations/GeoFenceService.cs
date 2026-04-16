using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.GeoFences;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 电子围栏服务实现
/// </summary>
public class GeoFenceService : IGeoFenceService
{
    private readonly AppDbContext _context;

    public GeoFenceService(AppDbContext context) => _context = context;

    /// <summary>
    /// 创建电子围栏
    /// </summary>
    public async Task<GeoFenceResponse> CreateFenceAsync(Guid creatorId, CreateGeoFenceRequest request)
    {
        // 检查老人是否已存在围栏（一个老人只能有一个围栏）
        var existingFence = await _context.GeoFences
            .FirstOrDefaultAsync(f => f.ElderId == request.ElderId);

        if (existingFence != null)
        {
            // 更新现有围栏
            existingFence.CenterLatitude = request.CenterLatitude;
            existingFence.CenterLongitude = request.CenterLongitude;
            existingFence.Radius = request.Radius;
            existingFence.IsEnabled = request.IsEnabled;
            existingFence.CreatedBy = creatorId;
            existingFence.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
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
        await _context.SaveChangesAsync();

        return MapToResponse(fence);
    }

    /// <summary>
    /// 获取老人的电子围栏
    /// </summary>
    public async Task<GeoFenceResponse?> GetElderFenceAsync(Guid elderId)
    {
        var fence = await _context.GeoFences
            .Include(f => f.Elder)
            .FirstOrDefaultAsync(f => f.ElderId == elderId);

        return fence == null ? null : MapToResponse(fence);
    }

    /// <summary>
    /// 更新电子围栏
    /// </summary>
    public async Task<GeoFenceResponse> UpdateFenceAsync(Guid fenceId, Guid operatorId, CreateGeoFenceRequest request)
    {
        var fence = await _context.GeoFences
            .Include(f => f.Elder)
            .FirstOrDefaultAsync(f => f.Id == fenceId)
            ?? throw new KeyNotFoundException("围栏不存在");

        // 验证操作者是否是创建者或家庭成员
        var isFamilyMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == operatorId && fm.FamilyId ==
                _context.FamilyMembers.Where(m => m.UserId == fence.ElderId).Select(m => m.FamilyId).FirstOrDefault());

        if (fence.CreatedBy != operatorId && !isFamilyMember)
            throw new UnauthorizedAccessException("无权修改此围栏");

        fence.CenterLatitude = request.CenterLatitude;
        fence.CenterLongitude = request.CenterLongitude;
        fence.Radius = request.Radius;
        fence.IsEnabled = request.IsEnabled;
        fence.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return MapToResponse(fence);
    }

    /// <summary>
    /// 删除电子围栏
    /// </summary>
    public async Task DeleteFenceAsync(Guid fenceId, Guid operatorId)
    {
        var fence = await _context.GeoFences
            .FirstOrDefaultAsync(f => f.Id == fenceId)
            ?? throw new KeyNotFoundException("围栏不存在");

        // 验证操作者是否是创建者或家庭成员
        var isFamilyMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == operatorId && fm.FamilyId ==
                _context.FamilyMembers.Where(m => m.UserId == fence.ElderId).Select(m => m.FamilyId).FirstOrDefault());

        if (fence.CreatedBy != operatorId && !isFamilyMember)
            throw new UnauthorizedAccessException("无权删除此围栏");

        _context.GeoFences.Remove(fence);
        await _context.SaveChangesAsync();
    }

    /// <summary>
    /// 检查用户是否超出围栏
    /// </summary>
    public async Task<(GeoFenceResponse? fence, double distance)?> CheckOutsideFenceAsync(Guid userId, double latitude, double longitude)
    {
        // 获取该用户的围栏
        var fence = await _context.GeoFences
            .Include(f => f.Elder)
            .FirstOrDefaultAsync(f => f.ElderId == userId && f.IsEnabled);

        if (fence == null) return null;

        // 计算当前位置与围栏中心的距离
        var distance = CalculateDistance(latitude, longitude, fence.CenterLatitude, fence.CenterLongitude);

        // 超出围栏
        if (distance > fence.Radius)
        {
            return (MapToResponse(fence), distance);
        }

        return null;
    }

    /// <summary>
    /// 使用 Haversine 公式计算两点间距离（米）
    /// </summary>
    /// <param name="lat1">点1纬度</param>
    /// <param name="lon1">点1经度</param>
    /// <param name="lat2">点2纬度</param>
    /// <param name="lon2">点2经度</param>
    /// <returns>距离（米）</returns>
    public static double CalculateDistance(double lat1, double lon1, double lat2, double lon2)
    {
        // 地球半径（米）
        const double EarthRadius = 6371000;

        // 将角度转换为弧度
        var lat1Rad = lat1 * Math.PI / 180;
        var lat2Rad = lat2 * Math.PI / 180;
        var deltaLat = (lat2 - lat1) * Math.PI / 180;
        var deltaLon = (lon2 - lon1) * Math.PI / 180;

        // Haversine 公式
        var a = Math.Sin(deltaLat / 2) * Math.Sin(deltaLat / 2) +
                Math.Cos(lat1Rad) * Math.Cos(lat2Rad) *
                Math.Sin(deltaLon / 2) * Math.Sin(deltaLon / 2);

        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

        return EarthRadius * c;
    }

    /// <summary>
    /// 映射到响应对象
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
}