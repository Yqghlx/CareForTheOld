using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Medication;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 用药提醒服务实现
/// </summary>
public class MedicationService : IMedicationService
{
    private readonly AppDbContext _context;
    private readonly IFamilyService _familyService;
    private readonly ILogger<MedicationService> _logger;

    public MedicationService(AppDbContext context, IFamilyService familyService, ILogger<MedicationService> logger)
    {
        _context = context;
        _familyService = familyService;
        _logger = logger;
    }

    /// <summary>
    /// 创建用药计划
    /// </summary>
    public async Task<MedicationPlanResponse> CreatePlanAsync(Guid operatorId, CreateMedicationPlanRequest request, CancellationToken cancellationToken = default)
    {
        // 验证老人是否存在
        var elder = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == request.ElderId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Medication.ElderNotFound);

        // 验证操作者权限（必须是老人的家庭成员）
        await _familyService.EnsureFamilyMemberAsync(request.ElderId, operatorId, cancellationToken);

        // 验证时间格式
        ValidateReminderTimes(request.ReminderTimes);

        var plan = new MedicationPlan
        {
            Id = Guid.NewGuid(),
            ElderId = request.ElderId,
            MedicineName = request.MedicineName,
            Dosage = request.Dosage,
            Frequency = request.Frequency,
            ReminderTimes = JsonSerializer.Serialize(request.ReminderTimes),
            StartDate = request.StartDate,
            EndDate = request.EndDate,
            IsActive = true,
        };
        plan.CreatedAt = plan.UpdatedAt = DateTime.UtcNow;

        _context.MedicationPlans.Add(plan);
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("用药计划已创建：老人 {ElderId}，药品 {MedicineName}，计划 {PlanId}", request.ElderId, request.MedicineName, plan.Id);

        return MapToPlanResponse(plan, elder.RealName);
    }

    /// <summary>
    /// 获取老人的用药计划列表
    /// </summary>
    public async Task<List<MedicationPlanResponse>> GetPlansByElderAsync(Guid elderId, Guid? operatorId = null, CancellationToken cancellationToken = default)
    {
        // 如果提供了 operatorId，验证是否为家庭成员
        if (operatorId.HasValue)
        {
            await _familyService.EnsureFamilyMemberAsync(elderId, operatorId.Value, cancellationToken);
        }

        return await _context.MedicationPlans
            .Include(p => p.Elder)
            .Where(p => p.ElderId == elderId && !p.IsDeleted)
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => MapToPlanResponseProjection(p))
            .ToListAsync(cancellationToken);
    }

    /// <summary>
    /// 更新用药计划
    /// </summary>
    public async Task<MedicationPlanResponse> UpdatePlanAsync(Guid planId, Guid operatorId, UpdateMedicationPlanRequest request, CancellationToken cancellationToken = default)
    {
        var plan = await _context.MedicationPlans
            .AsTracking()
            .Include(p => p.Elder)
            .FirstOrDefaultAsync(p => p.Id == planId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Medication.PlanNotFound);

        // 验证操作者权限
        await _familyService.EnsureFamilyMemberAsync(plan.ElderId, operatorId, cancellationToken);

        if (request.MedicineName is not null) plan.MedicineName = request.MedicineName;
        if (request.Dosage is not null) plan.Dosage = request.Dosage;
        if (request.Frequency is not null) plan.Frequency = request.Frequency.Value;
        if (request.ReminderTimes is not null)
        {
            ValidateReminderTimes(request.ReminderTimes);
            plan.ReminderTimes = JsonSerializer.Serialize(request.ReminderTimes);
        }
        if (request.EndDate is not null) plan.EndDate = request.EndDate;
        if (request.IsActive is not null) plan.IsActive = request.IsActive.Value;
        plan.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);
        return MapToPlanResponse(plan, plan.Elder.RealName);
    }

    /// <summary>
    /// 软删除用药计划
    /// </summary>
    public async Task DeletePlanAsync(Guid planId, Guid operatorId, CancellationToken cancellationToken = default)
    {
        var plan = await _context.MedicationPlans.AsTracking().FirstOrDefaultAsync(p => p.Id == planId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Medication.PlanNotFound);

        await _familyService.EnsureFamilyMemberAsync(plan.ElderId, operatorId, cancellationToken);

        // 软删除：标记为已删除，保留数据
        plan.IsDeleted = true;
        plan.DeletedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("用药计划已删除：计划 {PlanId}，操作者 {OperatorId}", planId, operatorId);
    }

    /// <summary>
    /// 记录用药日志（含并发冲突处理：计划 ID + 时间唯一约束）
    /// </summary>
    public async Task<MedicationLogResponse> RecordLogAsync(Guid operatorId, RecordMedicationLogRequest request, CancellationToken cancellationToken = default)
    {
        var plan = await _context.MedicationPlans
            .AsTracking()
            .Include(p => p.Elder)
            .FirstOrDefaultAsync(p => p.Id == request.PlanId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Medication.PlanNotFound);

        await _familyService.EnsureFamilyMemberAsync(plan.ElderId, operatorId, cancellationToken);

        // 检查是否已有该时间点的日志
        var existingLog = await _context.MedicationLogs
            .AsTracking()
            .FirstOrDefaultAsync(l => l.PlanId == request.PlanId && l.ScheduledAt == request.ScheduledAt, cancellationToken);

        if (existingLog is not null)
        {
            existingLog.Status = request.Status;
            existingLog.TakenAt = request.TakenAt ?? DateTime.UtcNow;
            existingLog.Note = request.Note;
            await _context.SaveChangesAsync(cancellationToken);
            return MapToLogResponse(existingLog, plan.MedicineName, plan.Elder.RealName);
        }

        var log = new MedicationLog
        {
            Id = Guid.NewGuid(),
            PlanId = request.PlanId,
            ElderId = plan.ElderId,
            Status = request.Status,
            ScheduledAt = request.ScheduledAt,
            TakenAt = request.TakenAt ?? (request.Status == MedicationStatus.Taken ? DateTime.UtcNow : null),
            Note = request.Note
        };

        _context.MedicationLogs.Add(log);

        try
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            // 并发场景：另一个请求已创建了相同记录，改为更新
            _context.MedicationLogs.Remove(log);
            var concurrentLog = await _context.MedicationLogs
                .AsTracking()
                .FirstAsync(l => l.PlanId == request.PlanId && l.ScheduledAt == request.ScheduledAt, cancellationToken);
            concurrentLog.Status = request.Status;
            concurrentLog.TakenAt = request.TakenAt ?? DateTime.UtcNow;
            concurrentLog.Note = request.Note;
            await _context.SaveChangesAsync(cancellationToken);
            return MapToLogResponse(concurrentLog, plan.MedicineName, plan.Elder.RealName);
        }

        return MapToLogResponse(log, plan.MedicineName, plan.Elder.RealName);
    }

    /// <summary>
    /// 获取用药日志列表
    /// </summary>
    public async Task<List<MedicationLogResponse>> GetLogsAsync(Guid elderId, DateOnly? date, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, Guid? operatorId = null, CancellationToken cancellationToken = default)
    {
        // 如果提供了 operatorId，验证是否为家庭成员
        if (operatorId.HasValue)
        {
            await _familyService.EnsureFamilyMemberAsync(elderId, operatorId.Value, cancellationToken);
        }

        var query = _context.MedicationLogs
            .Include(l => l.Plan)
            .Include(l => l.Elder)
            .Where(l => l.ElderId == elderId);

        if (date.HasValue)
        {
            var start = ToUtcDate(date.Value);
            var end = start.AddDays(1);
            query = query.Where(l => l.ScheduledAt >= start && l.ScheduledAt < end);
        }

        return await query
            .OrderByDescending(l => l.ScheduledAt)
            .Skip(skip)
            .Take(limit)
            .Select(l => MapToLogResponseProjection(l))
            .ToListAsync(cancellationToken);
    }

    /// <summary>
    /// 获取今日待服药列表
    /// </summary>
    public async Task<List<MedicationLogResponse>> GetTodayPendingAsync(Guid elderId, CancellationToken cancellationToken = default)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        // PostgreSQL timestamp with time zone 要求 DateTime.Kind 必须是 UTC
        var start = ToUtcDate(today);
        var end = start.AddDays(1);

        // 获取所有激活的计划
        var activePlans = await _context.MedicationPlans
            .Include(p => p.Elder)
            .Where(p => p.ElderId == elderId && p.IsActive && p.StartDate <= today)
            .ToListAsync(cancellationToken);

        // 批量查询所有相关计划的今日用药记录，避免 N+1 查询
        var planIds = activePlans.Select(p => p.Id).ToList();
        var allExistingLogs = await _context.MedicationLogs
            .Where(l => planIds.Contains(l.PlanId) && l.ScheduledAt >= start && l.ScheduledAt < end)
            .ToListAsync(cancellationToken);

        var pendingLogs = new List<MedicationLogResponse>();

        foreach (var plan in activePlans)
        {
            if (plan.EndDate.HasValue && plan.EndDate.Value < today) continue;

            var reminderTimes = DeserializeReminderTimes(plan.ReminderTimes);
            // 从批量查询结果中筛选当前计划的记录
            var existingLogs = allExistingLogs.Where(l => l.PlanId == plan.Id).ToList();

            foreach (var timeStr in reminderTimes)
            {
                if (!TimeOnly.TryParse(timeStr, out var time)) continue;

                var scheduledAt = DateTime.SpecifyKind(today.ToDateTime(time), DateTimeKind.Utc); // TimeOnly 组合，非午夜零点
                var existingLog = existingLogs.FirstOrDefault(l => l.ScheduledAt == scheduledAt);

                if (existingLog != null)
                {
                    // 已有记录，返回实际状态
                    pendingLogs.Add(new MedicationLogResponse
                    {
                        Id = existingLog.Id,
                        PlanId = plan.Id,
                        MedicineName = plan.MedicineName,
                        ElderId = elderId,
                        ElderName = plan.Elder.RealName,
                        Status = existingLog.Status,
                        ScheduledAt = existingLog.ScheduledAt,
                        TakenAt = existingLog.TakenAt,
                        Note = existingLog.Note
                    });
                }
                else
                {
                    // 无记录，返回待服药状态
                    pendingLogs.Add(new MedicationLogResponse
                    {
                        PlanId = plan.Id,
                        MedicineName = plan.MedicineName,
                        ElderId = elderId,
                        ElderName = plan.Elder.RealName,
                        Status = MedicationStatus.Missed,
                        ScheduledAt = scheduledAt
                    });
                }
            }
        }

        return pendingLogs.OrderBy(l => l.ScheduledAt).ToList();
    }

    /// <summary>
    /// 验证提醒时间格式
    /// </summary>
    private static void ValidateReminderTimes(List<string> times)
    {
        foreach (var time in times)
        {
            if (!TimeOnly.TryParse(time, out _))
                throw new ArgumentException($"{ErrorMessages.Medication.InvalidTimeFormat}: {time}");
        }
    }

    /// <summary>
    /// 反序列化提醒时间 JSON
    /// </summary>
    private static List<string> DeserializeReminderTimes(string json)
        => JsonSerializer.Deserialize<List<string>>(json) ?? [];

    /// <summary>
    /// 将 DateOnly 转换为 UTC DateTime（午夜零点），满足 PostgreSQL timestamp with time zone 要求
    /// </summary>
    private static DateTime ToUtcDate(DateOnly date)
        => DateTime.SpecifyKind(date.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc);

    private static MedicationPlanResponse MapToPlanResponse(MedicationPlan plan, string? elderName)
    {
        return new MedicationPlanResponse
        {
            Id = plan.Id,
            ElderId = plan.ElderId,
            ElderName = elderName,
            MedicineName = plan.MedicineName,
            Dosage = plan.Dosage,
            Frequency = plan.Frequency,
            ReminderTimes = DeserializeReminderTimes(plan.ReminderTimes),
            StartDate = plan.StartDate,
            EndDate = plan.EndDate,
            IsActive = plan.IsActive,
            CreatedAt = plan.CreatedAt,
            UpdatedAt = plan.UpdatedAt
        };
    }

    private static MedicationPlanResponse MapToPlanResponseProjection(MedicationPlan p)
        => MapToPlanResponse(p, p.Elder?.RealName);

    private static MedicationLogResponse MapToLogResponse(MedicationLog log, string medicineName, string? elderName)
    {
        return new MedicationLogResponse
        {
            Id = log.Id,
            PlanId = log.PlanId,
            MedicineName = medicineName,
            ElderId = log.ElderId,
            ElderName = elderName,
            Status = log.Status,
            ScheduledAt = log.ScheduledAt,
            TakenAt = log.TakenAt,
            Note = log.Note
        };
    }

    private static MedicationLogResponse MapToLogResponseProjection(MedicationLog l)
        => MapToLogResponse(l, l.Plan?.MedicineName ?? string.Empty, l.Elder?.RealName);
}