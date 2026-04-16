using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Health;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 健康记录服务实现
/// </summary>
public class HealthService : IHealthService
{
    private readonly AppDbContext _context;
    private readonly IHealthAlertService _alertService;

    public HealthService(AppDbContext context, IHealthAlertService alertService)
    {
        _context = context;
        _alertService = alertService;
    }

    public async Task<HealthRecordResponse> CreateRecordAsync(Guid userId, CreateHealthRecordRequest request)
    {
        // 验证必填字段
        ValidateHealthData(request);

        var record = new HealthRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = request.Type,
            Systolic = request.Systolic,
            Diastolic = request.Diastolic,
            BloodSugar = request.BloodSugar,
            HeartRate = request.HeartRate,
            Temperature = request.Temperature,
            Note = request.Note,
            RecordedAt = request.RecordedAt ?? DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow
        };

        _context.HealthRecords.Add(record);
        await _context.SaveChangesAsync();

        // 检查健康异常并通知子女
        var alertMessage = _alertService.CheckAbnormal(record);
        if (alertMessage != null)
        {
            // 异步发送预警通知，不阻塞主流程
            _ = _alertService.SendAlertToChildrenAsync(userId, record, alertMessage);
        }

        return await MapToResponse(record.Id) ?? throw new KeyNotFoundException("记录不存在");
    }

    public async Task<List<HealthRecordResponse>> GetUserRecordsAsync(Guid userId, HealthType? type, int limit = 50)
    {
        var query = _context.HealthRecords
            .Include(r => r.User)
            .Where(r => r.UserId == userId);

        if (type.HasValue)
            query = query.Where(r => r.Type == type.Value);

        return await query
            .OrderByDescending(r => r.RecordedAt)
            .Take(limit)
            .Select(r => MapToResponseProjection(r))
            .ToListAsync();
    }

    public async Task<List<HealthRecordResponse>> GetFamilyMemberRecordsAsync(Guid familyId, Guid memberId, HealthType? type, int limit = 50)
    {
        // 验证 memberId 是否属于该家庭
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId);

        if (!isMember)
            throw new UnauthorizedAccessException("该用户不是家庭成员");

        return await GetUserRecordsAsync(memberId, type, limit);
    }

    public async Task<List<HealthStatsResponse>> GetUserStatsAsync(Guid userId)
    {
        var records = await _context.HealthRecords
            .Where(r => r.UserId == userId)
            .ToListAsync();

        var stats = new List<HealthStatsResponse>();
        var now = DateTime.UtcNow;

        foreach (HealthType type in Enum.GetValues(typeof(HealthType)))
        {
            var typeRecords = records.Where(r => r.Type == type).ToList();
            if (typeRecords.Count == 0) continue;

            var statsResponse = new HealthStatsResponse
            {
                TypeName = GetTypeDisplayName(type),
                TotalCount = typeRecords.Count
            };

            // 根据类型计算平均值
            var recent7Days = typeRecords.Where(r => r.RecordedAt >= now.AddDays(-7)).ToList();
            var recent30Days = typeRecords.Where(r => r.RecordedAt >= now.AddDays(-30)).ToList();
            var latest = typeRecords.OrderByDescending(r => r.RecordedAt).First();

            statsResponse.LatestRecordedAt = latest.RecordedAt;

            switch (type)
            {
                case HealthType.BloodPressure:
                    statsResponse.LatestValue = latest.Systolic;
                    statsResponse.Average7Days = recent7Days.Count > 0 ? (decimal)recent7Days.Average(r => r.Systolic ?? 0) : null;
                    statsResponse.Average30Days = recent30Days.Count > 0 ? (decimal)recent30Days.Average(r => r.Systolic ?? 0) : null;
                    break;
                case HealthType.BloodSugar:
                    statsResponse.LatestValue = latest.BloodSugar;
                    statsResponse.Average7Days = recent7Days.Count > 0 ? recent7Days.Average(r => r.BloodSugar ?? 0m) : null;
                    statsResponse.Average30Days = recent30Days.Count > 0 ? recent30Days.Average(r => r.BloodSugar ?? 0m) : null;
                    break;
                case HealthType.HeartRate:
                    statsResponse.LatestValue = latest.HeartRate;
                    statsResponse.Average7Days = recent7Days.Count > 0 ? (decimal)recent7Days.Average(r => r.HeartRate ?? 0) : null;
                    statsResponse.Average30Days = recent30Days.Count > 0 ? (decimal)recent30Days.Average(r => r.HeartRate ?? 0) : null;
                    break;
                case HealthType.Temperature:
                    statsResponse.LatestValue = latest.Temperature;
                    statsResponse.Average7Days = recent7Days.Count > 0 ? recent7Days.Average(r => r.Temperature ?? 0m) : null;
                    statsResponse.Average30Days = recent30Days.Count > 0 ? recent30Days.Average(r => r.Temperature ?? 0m) : null;
                    break;
            }

            stats.Add(statsResponse);
        }

        return stats;
    }

    public async Task DeleteRecordAsync(Guid userId, Guid recordId)
    {
        var record = await _context.HealthRecords
            .FirstOrDefaultAsync(r => r.Id == recordId && r.UserId == userId)
            ?? throw new KeyNotFoundException("记录不存在或无权删除");

        _context.HealthRecords.Remove(record);
        await _context.SaveChangesAsync();
    }

    /// <summary>
    /// 验证健康数据必填字段
    /// </summary>
    private static void ValidateHealthData(CreateHealthRecordRequest request)
    {
        switch (request.Type)
        {
            case HealthType.BloodPressure:
                if (!request.Systolic.HasValue || !request.Diastolic.HasValue)
                    throw new ArgumentException("血压记录需要填写收缩压和舒张压");
                break;
            case HealthType.BloodSugar:
                if (!request.BloodSugar.HasValue)
                    throw new ArgumentException("血糖记录需要填写血糖值");
                break;
            case HealthType.HeartRate:
                if (!request.HeartRate.HasValue)
                    throw new ArgumentException("心率记录需要填写心率值");
                break;
            case HealthType.Temperature:
                if (!request.Temperature.HasValue)
                    throw new ArgumentException("体温记录需要填写体温值");
                break;
        }
    }

    private async Task<HealthRecordResponse?> MapToResponse(Guid recordId)
    {
        return await _context.HealthRecords
            .Include(r => r.User)
            .Where(r => r.Id == recordId)
            .Select(r => MapToResponseProjection(r))
            .FirstOrDefaultAsync();
    }

    private static HealthRecordResponse MapToResponseProjection(HealthRecord r)
    {
        return new HealthRecordResponse
        {
            Id = r.Id,
            UserId = r.UserId,
            RealName = r.User.RealName,
            Type = r.Type,
            Systolic = r.Systolic,
            Diastolic = r.Diastolic,
            BloodSugar = r.BloodSugar,
            HeartRate = r.HeartRate,
            Temperature = r.Temperature,
            Note = r.Note,
            RecordedAt = r.RecordedAt,
            CreatedAt = r.CreatedAt
        };
    }

    private static string GetTypeDisplayName(HealthType type)
    {
        return type switch
        {
            HealthType.BloodPressure => "血压",
            HealthType.BloodSugar => "血糖",
            HealthType.HeartRate => "心率",
            HealthType.Temperature => "体温",
            _ => type.ToString()
        };
    }
}