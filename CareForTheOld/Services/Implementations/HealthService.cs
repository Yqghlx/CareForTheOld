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
    private readonly ILogger<HealthService> _logger;

    public HealthService(AppDbContext context, IHealthAlertService alertService, ILogger<HealthService> logger)
    {
        _context = context;
        _alertService = alertService;
        _logger = logger;
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
            // 异步发送预警通知，不阻塞主流程，但捕获异常记录日志
            _ = Task.Run(async () =>
            {
                try
                {
                    await _alertService.SendAlertToChildrenAsync(userId, record, alertMessage);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "健康预警通知发送失败，用户 {UserId}", userId);
                }
            });
        }

        return await MapToResponse(record.Id) ?? throw new KeyNotFoundException("记录不存在");
    }

    public async Task<List<HealthRecordResponse>> GetUserRecordsAsync(Guid userId, HealthType? type, int skip = 0, int limit = 50)
    {
        var query = _context.HealthRecords
            .Include(r => r.User)
            .Where(r => r.UserId == userId && !r.IsDeleted);

        if (type.HasValue)
            query = query.Where(r => r.Type == type.Value);

        return await query
            .OrderByDescending(r => r.RecordedAt)
            .Skip(skip)
            .Take(limit)
            .Select(r => MapToResponseProjection(r))
            .ToListAsync();
    }

    public async Task<List<HealthRecordResponse>> GetFamilyMemberRecordsAsync(Guid familyId, Guid memberId, HealthType? type, int skip = 0, int limit = 50)
    {
        // 验证 memberId 是否属于该家庭
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId);

        if (!isMember)
            throw new UnauthorizedAccessException("该用户不是家庭成员");

        return await GetUserRecordsAsync(memberId, type, skip, limit);
    }

    public async Task<List<HealthStatsResponse>> GetUserStatsAsync(Guid userId)
    {
        var now = DateTime.UtcNow;
        var sevenDaysAgo = now.AddDays(-7);
        var thirtyDaysAgo = now.AddDays(-30);

        // 按类型分组聚合，避免全量加载到内存
        var typeGroups = await _context.HealthRecords
            .Where(r => r.UserId == userId && !r.IsDeleted)
            .GroupBy(r => r.Type)
            .Select(g => new
            {
                Type = g.Key,
                TotalCount = g.Count(),
                LatestRecordedAt = g.Max(r => r.RecordedAt),
                // 最新值通过子查询获取
                LatestSystolic = g.OrderByDescending(r => r.RecordedAt).Select(r => r.Systolic).FirstOrDefault(),
                LatestDiastolic = g.OrderByDescending(r => r.RecordedAt).Select(r => r.Diastolic).FirstOrDefault(),
                LatestBloodSugar = g.OrderByDescending(r => r.RecordedAt).Select(r => r.BloodSugar).FirstOrDefault(),
                LatestHeartRate = g.OrderByDescending(r => r.RecordedAt).Select(r => r.HeartRate).FirstOrDefault(),
                LatestTemperature = g.OrderByDescending(r => r.RecordedAt).Select(r => r.Temperature).FirstOrDefault(),
                Avg7Systolic = g.Where(r => r.RecordedAt >= sevenDaysAgo).Select(r => (double?)r.Systolic).Average(),
                Avg30Systolic = g.Where(r => r.RecordedAt >= thirtyDaysAgo).Select(r => (double?)r.Systolic).Average(),
                Avg7BloodSugar = g.Where(r => r.RecordedAt >= sevenDaysAgo).Select(r => (decimal?)r.BloodSugar).Average(),
                Avg30BloodSugar = g.Where(r => r.RecordedAt >= thirtyDaysAgo).Select(r => (decimal?)r.BloodSugar).Average(),
                Avg7HeartRate = g.Where(r => r.RecordedAt >= sevenDaysAgo).Select(r => (double?)r.HeartRate).Average(),
                Avg30HeartRate = g.Where(r => r.RecordedAt >= thirtyDaysAgo).Select(r => (double?)r.HeartRate).Average(),
                Avg7Temperature = g.Where(r => r.RecordedAt >= sevenDaysAgo).Select(r => (decimal?)r.Temperature).Average(),
                Avg30Temperature = g.Where(r => r.RecordedAt >= thirtyDaysAgo).Select(r => (decimal?)r.Temperature).Average(),
            })
            .ToListAsync();

        var stats = new List<HealthStatsResponse>();

        foreach (var g in typeGroups)
        {
            var statsResponse = new HealthStatsResponse
            {
                TypeName = GetTypeDisplayName(g.Type),
                TotalCount = g.TotalCount,
                LatestRecordedAt = g.LatestRecordedAt
            };

            switch (g.Type)
            {
                case HealthType.BloodPressure:
                    statsResponse.LatestValue = g.LatestSystolic;
                    statsResponse.Average7Days = g.Avg7Systolic.HasValue ? (decimal)g.Avg7Systolic.Value : null;
                    statsResponse.Average30Days = g.Avg30Systolic.HasValue ? (decimal)g.Avg30Systolic.Value : null;
                    break;
                case HealthType.BloodSugar:
                    statsResponse.LatestValue = g.LatestBloodSugar;
                    statsResponse.Average7Days = g.Avg7BloodSugar;
                    statsResponse.Average30Days = g.Avg30BloodSugar;
                    break;
                case HealthType.HeartRate:
                    statsResponse.LatestValue = g.LatestHeartRate;
                    statsResponse.Average7Days = g.Avg7HeartRate.HasValue ? (decimal)g.Avg7HeartRate.Value : null;
                    statsResponse.Average30Days = g.Avg30HeartRate.HasValue ? (decimal)g.Avg30HeartRate.Value : null;
                    break;
                case HealthType.Temperature:
                    statsResponse.LatestValue = g.LatestTemperature;
                    statsResponse.Average7Days = g.Avg7Temperature;
                    statsResponse.Average30Days = g.Avg30Temperature;
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

        // 软删除：标记为已删除，保留数据
        record.IsDeleted = true;
        record.DeletedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
    }

    /// <summary>
    /// 验证健康数据必填字段和数值范围
    /// </summary>
    private static void ValidateHealthData(CreateHealthRecordRequest request)
    {
        switch (request.Type)
        {
            case HealthType.BloodPressure:
                if (!request.Systolic.HasValue || !request.Diastolic.HasValue)
                    throw new ArgumentException("血压记录需要填写收缩压和舒张压");
                if (request.Systolic.Value < 60 || request.Systolic.Value > 300)
                    throw new ArgumentException("收缩压数值异常（正常范围 60-300 mmHg）");
                if (request.Diastolic.Value < 30 || request.Diastolic.Value > 200)
                    throw new ArgumentException("舒张压数值异常（正常范围 30-200 mmHg）");
                break;
            case HealthType.BloodSugar:
                if (!request.BloodSugar.HasValue)
                    throw new ArgumentException("血糖记录需要填写血糖值");
                if (request.BloodSugar.Value < 1.0m || request.BloodSugar.Value > 35.0m)
                    throw new ArgumentException("血糖数值异常（正常范围 1.0-35.0 mmol/L）");
                break;
            case HealthType.HeartRate:
                if (!request.HeartRate.HasValue)
                    throw new ArgumentException("心率记录需要填写心率值");
                if (request.HeartRate.Value < 30 || request.HeartRate.Value > 250)
                    throw new ArgumentException("心率数值异常（正常范围 30-250 次/分钟）");
                break;
            case HealthType.Temperature:
                if (!request.Temperature.HasValue)
                    throw new ArgumentException("体温记录需要填写体温值");
                if (request.Temperature.Value < 34.0m || request.Temperature.Value > 43.0m)
                    throw new ArgumentException("体温数值异常（正常范围 34.0-43.0 °C）");
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