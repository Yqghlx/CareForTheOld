using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
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

    /// <summary>
    /// 创建健康记录：包含数据验证和异常预警通知，异常时通过 Hangfire 异步推送
    /// </summary>
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

        _logger.LogInformation("健康记录已创建：用户 {UserId}，类型 {Type}，记录 {RecordId}", userId, request.Type, record.Id);

        // 检查健康异常并通知子女
        var alertMessage = _alertService.CheckAbnormal(record);
        if (alertMessage != null)
        {
            // 通过 Hangfire 异步发送预警通知，支持持久化和自动重试
            HangfireJobHelper.EnqueueSafely(
                () => SendHealthAlertJobAsync(userId, record.Id, alertMessage),
                "健康预警", _logger, userId);
        }

        return await MapToResponse(record.Id) ?? throw new KeyNotFoundException(ErrorMessages.Health.RecordNotFound);
    }

    /// <summary>
    /// Hangfire 后台任务：发送健康预警通知
    /// 通过 recordId 重新获取记录，避免序列化复杂对象
    /// </summary>
    public async Task SendHealthAlertJobAsync(Guid userId, Guid recordId, string alertMessage)
    {
        try
        {
            var record = await _context.HealthRecords.FindAsync(recordId);
            if (record == null)
            {
                _logger.LogWarning("健康预警任务：记录 {RecordId} 不存在，跳过通知", recordId);
                return;
            }

            await _alertService.SendAlertToChildrenAsync(userId, record, alertMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "健康预警通知发送失败，用户 {UserId}，记录 {RecordId}", userId, recordId);
        }
    }

    /// <summary>
    /// 获取用户健康记录列表：支持按类型筛选和分页
    /// </summary>
    public async Task<List<HealthRecordResponse>> GetUserRecordsAsync(Guid userId, HealthType? type, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize)
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

    /// <summary>
    /// 获取家庭成员的健康记录：需验证目标用户是否属于该家庭
    /// </summary>
    public async Task<List<HealthRecordResponse>> GetFamilyMemberRecordsAsync(Guid familyId, Guid memberId, HealthType? type, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize)
    {
        // 验证 memberId 是否属于该家庭
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId);

        if (!isMember)
            throw new UnauthorizedAccessException(ErrorMessages.Health.NotFamilyMember);

        return await GetUserRecordsAsync(memberId, type, skip, limit);
    }

    /// <summary>
    /// 获取用户健康统计数据：包括每种类型的最新值、7天和30天均值
    /// </summary>
    public async Task<List<HealthStatsResponse>> GetUserStatsAsync(Guid userId)
    {
        var now = DateTime.UtcNow;
        var sevenDaysAgo = now.AddDays(-AppConstants.HealthStatsDays.RecentDays);
        var thirtyDaysAgo = now.AddDays(-AppConstants.HealthStatsDays.LongTermDays);

        // 第一步：获取每种类型的最新记录（一次查询，避免分组内重复排序）
        var latestRecords = await _context.HealthRecords
            .Where(r => r.UserId == userId && !r.IsDeleted)
            .GroupBy(r => r.Type)
            .Select(g => new { Type = g.Key, Record = g.OrderByDescending(r => r.RecordedAt).FirstOrDefault() })
            .ToListAsync();

        // 第二步：按类型分组聚合统计值（均值等）
        var typeGroups = await _context.HealthRecords
            .Where(r => r.UserId == userId && !r.IsDeleted)
            .GroupBy(r => r.Type)
            .Select(g => new
            {
                Type = g.Key,
                TotalCount = g.Count(),
                LatestRecordedAt = g.Max(r => r.RecordedAt),
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

        // 合并最新记录和统计数据
        var latestByType = latestRecords.ToDictionary(l => l.Type, l => l.Record);

        var stats = new List<HealthStatsResponse>();

        foreach (var g in typeGroups)
        {
            var statsResponse = new HealthStatsResponse
            {
                TypeName = GetTypeDisplayName(g.Type),
                TotalCount = g.TotalCount,
                LatestRecordedAt = g.LatestRecordedAt
            };

            // 从最新记录中提取对应字段
            var latest = latestByType.GetValueOrDefault(g.Type);

            switch (g.Type)
            {
                case HealthType.BloodPressure:
                    statsResponse.LatestValue = latest?.Systolic;
                    statsResponse.Average7Days = g.Avg7Systolic.HasValue ? (decimal)g.Avg7Systolic.Value : null;
                    statsResponse.Average30Days = g.Avg30Systolic.HasValue ? (decimal)g.Avg30Systolic.Value : null;
                    break;
                case HealthType.BloodSugar:
                    statsResponse.LatestValue = latest?.BloodSugar;
                    statsResponse.Average7Days = g.Avg7BloodSugar;
                    statsResponse.Average30Days = g.Avg30BloodSugar;
                    break;
                case HealthType.HeartRate:
                    statsResponse.LatestValue = latest?.HeartRate;
                    statsResponse.Average7Days = g.Avg7HeartRate.HasValue ? (decimal)g.Avg7HeartRate.Value : null;
                    statsResponse.Average30Days = g.Avg30HeartRate.HasValue ? (decimal)g.Avg30HeartRate.Value : null;
                    break;
                case HealthType.Temperature:
                    statsResponse.LatestValue = latest?.Temperature;
                    statsResponse.Average7Days = g.Avg7Temperature;
                    statsResponse.Average30Days = g.Avg30Temperature;
                    break;
            }

            stats.Add(statsResponse);
        }

        return stats;
    }

    /// <summary>
    /// 软删除健康记录：标记为已删除并保留原始数据
    /// </summary>
    public async Task DeleteRecordAsync(Guid userId, Guid recordId)
    {
        var record = await _context.HealthRecords
            .AsTracking()
            .FirstOrDefaultAsync(r => r.Id == recordId && r.UserId == userId)
            ?? throw new KeyNotFoundException(ErrorMessages.Health.RecordNotFoundOrNoPermission);

        // 软删除：标记为已删除，保留数据
        record.IsDeleted = true;
        record.DeletedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("健康记录已删除：用户 {UserId}，记录 {RecordId}", userId, recordId);
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
                    throw new ArgumentException(ErrorMessages.Health.BloodPressureRequired);
                if (request.Systolic.Value < AppConstants.HealthInputValidation.SystolicMin ||
                    request.Systolic.Value > AppConstants.HealthInputValidation.SystolicMax)
                    throw new ArgumentException(ErrorMessages.Health.SystolicOutOfRange);
                if (request.Diastolic.Value < AppConstants.HealthInputValidation.DiastolicMin ||
                    request.Diastolic.Value > AppConstants.HealthInputValidation.DiastolicMax)
                    throw new ArgumentException(ErrorMessages.Health.DiastolicOutOfRange);
                break;
            case HealthType.BloodSugar:
                if (!request.BloodSugar.HasValue)
                    throw new ArgumentException(ErrorMessages.Health.BloodSugarRequired);
                if (request.BloodSugar.Value < AppConstants.HealthInputValidation.BloodSugarMin ||
                    request.BloodSugar.Value > AppConstants.HealthInputValidation.BloodSugarMax)
                    throw new ArgumentException(ErrorMessages.Health.BloodSugarOutOfRange);
                break;
            case HealthType.HeartRate:
                if (!request.HeartRate.HasValue)
                    throw new ArgumentException(ErrorMessages.Health.HeartRateRequired);
                if (request.HeartRate.Value < AppConstants.HealthInputValidation.HeartRateMin ||
                    request.HeartRate.Value > AppConstants.HealthInputValidation.HeartRateMax)
                    throw new ArgumentException(ErrorMessages.Health.HeartRateOutOfRange);
                break;
            case HealthType.Temperature:
                if (!request.Temperature.HasValue)
                    throw new ArgumentException(ErrorMessages.Health.TemperatureRequired);
                if (request.Temperature.Value < AppConstants.HealthInputValidation.TemperatureMin ||
                    request.Temperature.Value > AppConstants.HealthInputValidation.TemperatureMax)
                    throw new ArgumentException(ErrorMessages.Health.TemperatureOutOfRange);
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
            HealthType.BloodPressure => AppConstants.HealthTypeLabels.BloodPressure,
            HealthType.BloodSugar => AppConstants.HealthTypeLabels.BloodSugar,
            HealthType.HeartRate => AppConstants.HealthTypeLabels.HeartRate,
            HealthType.Temperature => AppConstants.HealthTypeLabels.Temperature,
            _ => type.ToString()
        };
    }
}