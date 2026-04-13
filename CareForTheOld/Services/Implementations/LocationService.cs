using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 位置服务实现
/// </summary>
public class LocationService : ILocationService
{
    private readonly AppDbContext _context;

    public LocationService(AppDbContext context) => _context = context;

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
}