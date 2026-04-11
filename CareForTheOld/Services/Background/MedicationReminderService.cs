using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace CareForTheOld.Services.Background;

/// <summary>
/// 用药提醒后台服务
/// 每分钟检查是否有需要提醒的用药计划
/// </summary>
public class MedicationReminderService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<MedicationReminderService> _logger;

    public MedicationReminderService(IServiceProvider serviceProvider, ILogger<MedicationReminderService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("用药提醒后台服务启动");

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

                // 计算提醒时间（提前5分钟提醒）
                var reminderTimeWithBuffer = reminderTime.AddMinutes(-5);

                // 检查是否在当前时间的1分钟窗口内
                if (currentTime >= reminderTimeWithBuffer && currentTime < reminderTimeWithBuffer.AddMinutes(1))
                {
                    var scheduledAt = today.ToDateTime(reminderTime);

                    // 检查是否已发送过提醒（通过检查日志是否存在）
                    var existingLog = await context.MedicationLogs
                        .AnyAsync(l => l.PlanId == plan.Id && l.ScheduledAt == scheduledAt, stoppingToken);

                    if (!existingLog)
                    {
                        await SendReminderAsync(notificationService, context, plan, scheduledAt, stoppingToken);
                    }
                }
            }
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

        // 发送给老人
        await notificationService.SendToUserAsync(plan.ElderId, message.Type, message);

        // 获取老人的家庭，通知家庭成员
        var familyMembers = await context.FamilyMembers
            .Where(fm => fm.UserId == plan.ElderId)
            .ToListAsync(stoppingToken);

        foreach (var member in familyMembers)
        {
            // 通知其他家庭成员（子女）
            var otherMembers = await context.FamilyMembers
                .Where(fm => fm.FamilyId == member.FamilyId && fm.UserId != plan.ElderId)
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
                await notificationService.SendToUserAsync(other.UserId, familyMessage.Type, familyMessage);
            }
        }

        _logger.LogInformation("发送用药提醒: 用户 {ElderId}, 药品 {MedicineName}, 时间 {ScheduledAt}",
            plan.ElderId, plan.MedicineName, scheduledAt);
    }
}