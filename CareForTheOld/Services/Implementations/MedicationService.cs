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

    public MedicationService(AppDbContext context) => _context = context;

    public async Task<MedicationPlanResponse> CreatePlanAsync(Guid operatorId, CreateMedicationPlanRequest request)
    {
        // 验证老人是否存在
        var elder = await _context.Users.FindAsync(request.ElderId)
            ?? throw new KeyNotFoundException("老人用户不存在");

        // 验证操作者权限（必须是老人的家庭成员）
        await EnsureFamilyMemberAsync(request.ElderId, operatorId);

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
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.MedicationPlans.Add(plan);
        await _context.SaveChangesAsync();

        return MapToPlanResponse(plan, elder.RealName);
    }

    public async Task<List<MedicationPlanResponse>> GetPlansByElderAsync(Guid elderId, Guid? operatorId = null)
    {
        // 如果提供了 operatorId，验证是否为家庭成员
        if (operatorId.HasValue)
        {
            await EnsureFamilyMemberAsync(elderId, operatorId.Value);
        }

        return await _context.MedicationPlans
            .Include(p => p.Elder)
            .Where(p => p.ElderId == elderId && !p.IsDeleted)
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => MapToPlanResponseProjection(p))
            .ToListAsync();
    }

    public async Task<MedicationPlanResponse> UpdatePlanAsync(Guid planId, Guid operatorId, UpdateMedicationPlanRequest request)
    {
        var plan = await _context.MedicationPlans
            .Include(p => p.Elder)
            .FirstOrDefaultAsync(p => p.Id == planId)
            ?? throw new KeyNotFoundException("用药计划不存在");

        // 验证操作者权限
        await EnsureFamilyMemberAsync(plan.ElderId, operatorId);

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

        await _context.SaveChangesAsync();
        return MapToPlanResponse(plan, plan.Elder.RealName);
    }

    public async Task DeletePlanAsync(Guid planId, Guid operatorId)
    {
        var plan = await _context.MedicationPlans.FindAsync(planId)
            ?? throw new KeyNotFoundException("用药计划不存在");

        await EnsureFamilyMemberAsync(plan.ElderId, operatorId);

        // 软删除：标记为已删除，保留数据
        plan.IsDeleted = true;
        plan.DeletedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
    }

    public async Task<MedicationLogResponse> RecordLogAsync(Guid operatorId, RecordMedicationLogRequest request)
    {
        var plan = await _context.MedicationPlans
            .Include(p => p.Elder)
            .FirstOrDefaultAsync(p => p.Id == request.PlanId)
            ?? throw new KeyNotFoundException("用药计划不存在");

        await EnsureFamilyMemberAsync(plan.ElderId, operatorId);

        // 检查是否已有该时间点的日志
        var existingLog = await _context.MedicationLogs
            .FirstOrDefaultAsync(l => l.PlanId == request.PlanId && l.ScheduledAt == request.ScheduledAt);

        if (existingLog is not null)
        {
            existingLog.Status = request.Status;
            existingLog.TakenAt = request.TakenAt ?? DateTime.UtcNow;
            existingLog.Note = request.Note;
            await _context.SaveChangesAsync();
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
        await _context.SaveChangesAsync();

        return MapToLogResponse(log, plan.MedicineName, plan.Elder.RealName);
    }

    public async Task<List<MedicationLogResponse>> GetLogsAsync(Guid elderId, DateOnly? date, int skip = 0, int limit = 50, Guid? operatorId = null)
    {
        // 如果提供了 operatorId，验证是否为家庭成员
        if (operatorId.HasValue)
        {
            await EnsureFamilyMemberAsync(elderId, operatorId.Value);
        }

        var query = _context.MedicationLogs
            .Include(l => l.Plan)
            .Include(l => l.Elder)
            .Where(l => l.ElderId == elderId);

        if (date.HasValue)
        {
            var start = DateTime.SpecifyKind(date.Value.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc);
            var end = start.AddDays(1);
            query = query.Where(l => l.ScheduledAt >= start && l.ScheduledAt < end);
        }

        return await query
            .OrderByDescending(l => l.ScheduledAt)
            .Skip(skip)
            .Take(limit)
            .Select(l => MapToLogResponseProjection(l))
            .ToListAsync();
    }

    public async Task<List<MedicationLogResponse>> GetTodayPendingAsync(Guid elderId)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        // PostgreSQL timestamp with time zone 要求 DateTime.Kind 必须是 UTC
        var start = DateTime.SpecifyKind(today.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc);
        var end = start.AddDays(1);

        // 获取所有激活的计划
        var activePlans = await _context.MedicationPlans
            .Include(p => p.Elder)
            .Where(p => p.ElderId == elderId && p.IsActive && p.StartDate <= today)
            .ToListAsync();

        // 批量查询所有相关计划的今日用药记录，避免 N+1 查询
        var planIds = activePlans.Select(p => p.Id).ToList();
        var allExistingLogs = await _context.MedicationLogs
            .Where(l => planIds.Contains(l.PlanId) && l.ScheduledAt >= start && l.ScheduledAt < end)
            .ToListAsync();

        var pendingLogs = new List<MedicationLogResponse>();

        foreach (var plan in activePlans)
        {
            if (plan.EndDate.HasValue && plan.EndDate.Value < today) continue;

            var reminderTimes = JsonSerializer.Deserialize<List<string>>(plan.ReminderTimes) ?? new();
            // 从批量查询结果中筛选当前计划的记录
            var existingLogs = allExistingLogs.Where(l => l.PlanId == plan.Id).ToList();

            foreach (var timeStr in reminderTimes)
            {
                if (!TimeOnly.TryParse(timeStr, out var time)) continue;

                var scheduledAt = DateTime.SpecifyKind(today.ToDateTime(time), DateTimeKind.Utc);
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
    /// 验证操作者是老人的家庭成员（拆分子查询为两次独立查询，提升性能）
    /// </summary>
    private async Task EnsureFamilyMemberAsync(Guid elderId, Guid operatorId)
    {
        // 老人本人可以操作
        if (elderId == operatorId) return;

        // 先查操作者所在家庭，再验证老人是否同家庭
        var operatorFamilyId = await _context.FamilyMembers
            .Where(fm => fm.UserId == operatorId)
            .Select(fm => fm.FamilyId)
            .FirstOrDefaultAsync();

        if (operatorFamilyId == Guid.Empty)
            throw new UnauthorizedAccessException("您不是该老人的家庭成员，无权操作");

        var isInSameFamily = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == elderId && fm.FamilyId == operatorFamilyId);

        if (!isInSameFamily)
            throw new UnauthorizedAccessException("您不是该老人的家庭成员，无权操作");
    }

    /// <summary>
    /// 验证提醒时间格式
    /// </summary>
    private static void ValidateReminderTimes(List<string> times)
    {
        foreach (var time in times)
        {
            if (!TimeOnly.TryParse(time, out _))
                throw new ArgumentException($"时间格式错误: {time}，正确格式如 08:00");
        }
    }

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
            ReminderTimes = JsonSerializer.Deserialize<List<string>>(plan.ReminderTimes) ?? new(),
            StartDate = plan.StartDate,
            EndDate = plan.EndDate,
            IsActive = plan.IsActive,
            CreatedAt = plan.CreatedAt,
            UpdatedAt = plan.UpdatedAt
        };
    }

    private static MedicationPlanResponse MapToPlanResponseProjection(MedicationPlan p)
    {
        return new MedicationPlanResponse
        {
            Id = p.Id,
            ElderId = p.ElderId,
            ElderName = p.Elder.RealName,
            MedicineName = p.MedicineName,
            Dosage = p.Dosage,
            Frequency = p.Frequency,
            ReminderTimes = JsonSerializer.Deserialize<List<string>>(p.ReminderTimes) ?? new(),
            StartDate = p.StartDate,
            EndDate = p.EndDate,
            IsActive = p.IsActive,
            CreatedAt = p.CreatedAt,
            UpdatedAt = p.UpdatedAt
        };
    }

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
    {
        return new MedicationLogResponse
        {
            Id = l.Id,
            PlanId = l.PlanId,
            MedicineName = l.Plan.MedicineName,
            ElderId = l.ElderId,
            ElderName = l.Elder.RealName,
            Status = l.Status,
            ScheduledAt = l.ScheduledAt,
            TakenAt = l.TakenAt,
            Note = l.Note
        };
    }
}