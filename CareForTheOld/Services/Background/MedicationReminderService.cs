using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using System.Text.Json;

namespace CareForTheOld.Services.Background;

/// <summary>
/// 用药提醒任务
/// 既可作为 Hangfire RecurringJob 运行（生产环境），也可作为 IHostedService 运行（开发/回退）
///
/// 支持多级提醒：
/// 1. 首次提醒：计划服药时间前 N 分钟推送通知（默认 5 分钟）
/// 2. 二次提醒：首次提醒后 10 分钟未确认，再次强提醒
/// 3. 子女介入：首次提醒后 30 分钟仍未确认，通知子女跟进
/// </summary>
public class MedicationReminderService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<MedicationReminderService> _logger;
    private readonly int _advanceMinutes;

    public MedicationReminderService(
        IServiceProvider serviceProvider,
        ILogger<MedicationReminderService> logger,
        IConfiguration configuration)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _advanceMinutes = configuration.GetValue("MedicationReminder:AdvanceMinutes", 5);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("用药提醒后台服务启动（IHostedService 模式）");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CheckAndSendRemindersAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "用药提醒检查出错");
            }

            // 每分钟检查一次
            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }

        _logger.LogInformation("用药提醒后台服务停止");
    }

    /// <summary>
    /// Hangfire RecurringJob 入口方法（供 Hangfire 调度调用）
    /// </summary>
    public async Task ExecuteHangfireJobAsync()
    {
        _logger.LogDebug("Hangfire 用药提醒任务执行");
        await CheckAndSendRemindersAsync(CancellationToken.None);
    }

    /// <summary>
    /// 检查并发送用药提醒
    /// </summary>
    private async Task CheckAndSendRemindersAsync(CancellationToken stoppingToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        var now = DateTime.UtcNow;
        var today = DateOnly.FromDateTime(now);
        var currentTime = TimeOnly.FromDateTime(now);

        // 获取所有激活的用药计划
        var activePlans = await context.MedicationPlans
            .Include(p => p.Elder)
            .Where(p => p.IsActive && p.StartDate <= today)
            .ToListAsync(stoppingToken);

        foreach (var plan in activePlans)
        {
            // 检查是否已过期
            if (plan.EndDate.HasValue && plan.EndDate.Value < today) continue;

            var reminderTimes = JsonSerializer.Deserialize<List<string>>(plan.ReminderTimes) ?? new();

            foreach (var timeStr in reminderTimes)
            {
                if (!TimeOnly.TryParse(timeStr, out var reminderTime)) continue;

                // 计算提醒时间（提前配置的分钟数提醒）
                var reminderTimeWithBuffer = reminderTime.AddMinutes(-_advanceMinutes);

                // 检查是否在当前时间的1分钟窗口内
                if (currentTime >= reminderTimeWithBuffer && currentTime < reminderTimeWithBuffer.AddMinutes(1))
                {
                    var scheduledAt = DateTime.SpecifyKind(today.ToDateTime(reminderTime), DateTimeKind.Utc);

                    // 检查是否已发送过提醒（通过检查日志是否存在）
                    var existingLog = await context.MedicationLogs
                        .AnyAsync(l => l.PlanId == plan.Id && l.ScheduledAt == scheduledAt, stoppingToken);

                    if (!existingLog)
                    {
                        await SendReminderAsync(notificationService, context, plan, scheduledAt, stoppingToken);

                        // 调度延迟检查任务：10分钟后二次提醒，30分钟后通知子女
                        ScheduleFollowUpChecks(plan, scheduledAt);
                    }
                }
            }
        }
    }

    /// <summary>
    /// 调度延迟的跟进检查任务（Hangfire 延迟任务）
    /// </summary>
    private void ScheduleFollowUpChecks(MedicationPlan plan, DateTime scheduledAt)
    {
        try
        {
            // 10 分钟后检查是否已服药，未服则二次提醒
            BackgroundJob.Schedule<MedicationReminderService>(
                svc => svc.CheckAndSendFollowUpAsync(plan.ElderId, plan.Id, scheduledAt, isEscalation: false),
                TimeSpan.FromMinutes(10));

            // 30 分钟后检查是否已服药，未服则通知子女
            BackgroundJob.Schedule<MedicationReminderService>(
                svc => svc.CheckAndSendFollowUpAsync(plan.ElderId, plan.Id, scheduledAt, isEscalation: true),
                TimeSpan.FromMinutes(30));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "调度用药跟进任务失败（非测试环境忽略）");
        }
    }

    /// <summary>
    /// Hangfire 延迟任务入口：检查用药状态并发送跟进提醒
    ///
    /// isEscalation=false → 二次提醒（发送给老人）
    /// isEscalation=true  → 子女介入（发送给子女）
    /// </summary>
    public async Task CheckAndSendFollowUpAsync(Guid elderId, Guid planId, DateTime scheduledAt, bool isEscalation)
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        // 检查老人是否已服药
        var hasTaken = await context.MedicationLogs
            .AnyAsync(l => l.PlanId == planId && l.ScheduledAt == scheduledAt
                         && (l.Status == MedicationStatus.Taken));

        if (hasTaken)
        {
            _logger.LogDebug("[用药跟进] 老人 {ElderId} 已服药，跳过跟进", elderId);
            return;
        }

        // 查询用药计划信息
        var plan = await context.MedicationPlans
            .Include(p => p.Elder)
            .FirstOrDefaultAsync(p => p.Id == planId);

        if (plan == null) return;

        var elderName = plan.Elder?.RealName ?? "老人";

        if (!isEscalation)
        {
            // 二次提醒：再次通知老人
            await SendWithRetryAsync(
                () => notificationService.SendToUserAsync(elderId, "MedicationReminderUrgent", new
                {
                    Title = "用药提醒（再次提醒）",
                    Content = $"您还未服用 {plan.MedicineName}（{plan.Dosage}），请尽快服药。",
                    PlanId = planId,
                    MedicineName = plan.MedicineName,
                    ScheduledAt = scheduledAt,
                    ReminderLevel = "Secondary"
                }),
                $"二次用药提醒-{elderId}");

            _logger.LogInformation("[用药跟进] 已发送二次提醒: 老人 {ElderId}, 药品 {Medicine}",
                elderId, plan.MedicineName);
        }
        else
        {
            // 子女介入：通知子女老人未服药
            var familyMembers = await context.FamilyMembers
                .Where(fm => fm.UserId == elderId)
                .ToListAsync();

            foreach (var member in familyMembers)
            {
                var children = await context.FamilyMembers
                    .Where(fm => fm.FamilyId == member.FamilyId && fm.UserId != elderId)
                    .ToListAsync();

                foreach (var child in children)
                {
                    await SendWithRetryAsync(
                        () => notificationService.SendToUserAsync(child.UserId, "MedicationMissed", new
                        {
                            Title = "老人未服药提醒",
                            Content = $"{elderName} 在 {scheduledAt:HH:mm} 的 {plan.MedicineName}（{plan.Dosage}）已超过 30 分钟未确认服药，请电话确认。",
                            ElderId = elderId,
                            ElderName = elderName,
                            PlanId = planId,
                            MedicineName = plan.MedicineName,
                            ScheduledAt = scheduledAt,
                            AlertLevel = "Warning"
                        }),
                        $"子女未服药通知-{child.UserId}");
                }
            }

            _logger.LogWarning("[用药跟进] 已通知子女: 老人 {ElderId} 超过 30 分钟未服 {Medicine}",
                elderId, plan.MedicineName);
        }
    }

    /// <summary>
    /// 发送用药提醒
    /// </summary>
    private async Task SendReminderAsync(
        INotificationService notificationService,
        AppDbContext context,
        MedicationPlan plan,
        DateTime scheduledAt,
        CancellationToken stoppingToken)
    {
        var message = new NotificationMessage
        {
            Type = "MedicationReminder",
            Title = "用药提醒",
            Content = $"请按时服用 {plan.MedicineName}，剂量：{plan.Dosage}",
            Timestamp = DateTime.UtcNow,
            Data = new
            {
                PlanId = plan.Id,
                MedicineName = plan.MedicineName,
                Dosage = plan.Dosage,
                ScheduledAt = scheduledAt
            }
        };

        // 发送给老人（含重试逻辑）
        await SendWithRetryAsync(() => notificationService.SendToUserAsync(plan.ElderId, message.Type, message),
            $"老人用药提醒-{plan.ElderId}");

        // 批量查询老人所在的所有家庭，然后一次性查出所有需要通知的子女
        var familyIds = await context.FamilyMembers
            .Where(fm => fm.UserId == plan.ElderId)
            .Select(fm => fm.FamilyId)
            .ToListAsync(stoppingToken);

        if (familyIds.Count > 0)
        {
            var otherMembers = await context.FamilyMembers
                .Where(fm => familyIds.Contains(fm.FamilyId) && fm.UserId != plan.ElderId)
                .ToListAsync(stoppingToken);

            foreach (var other in otherMembers)
            {
                var familyMessage = new NotificationMessage
                {
                    Type = "MedicationReminderFamily",
                    Title = "老人用药提醒",
                    Content = $"{plan.Elder.RealName} 应服用 {plan.MedicineName}",
                    Timestamp = DateTime.UtcNow,
                    Data = new
                    {
                        ElderId = plan.ElderId,
                        ElderName = plan.Elder.RealName,
                        PlanId = plan.Id,
                        MedicineName = plan.MedicineName,
                        ScheduledAt = scheduledAt
                    }
                };
                await SendWithRetryAsync(() => notificationService.SendToUserAsync(other.UserId, familyMessage.Type, familyMessage),
                    $"家庭成员用药提醒-{other.UserId}");
            }
        }

        _logger.LogInformation("发送用药提醒: 用户 {ElderId}, 药品 {MedicineName}, 时间 {ScheduledAt}",
            plan.ElderId, plan.MedicineName, scheduledAt);
    }

    /// <summary>
    /// 带重试的通知发送方法，最多重试3次，每次间隔1秒
    /// </summary>
    private async Task SendWithRetryAsync(Func<Task> sendAction, string description)
    {
        const int maxRetries = 3;
        for (int attempt = 1; attempt <= maxRetries; attempt++)
        {
            try
            {
                await sendAction();
                return; // 发送成功，直接返回
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "通知发送失败（第 {Attempt}/{MaxRetries} 次）: {Description}",
                    attempt, maxRetries, description);

                if (attempt < maxRetries)
                {
                    await Task.Delay(TimeSpan.FromSeconds(1));
                }
                else
                {
                    _logger.LogError(ex, "通知发送最终失败（已重试 {MaxRetries} 次）: {Description}",
                        maxRetries, description);
                }
            }
        }
    }
}