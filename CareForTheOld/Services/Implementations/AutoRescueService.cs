using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 自动救援服务 — 地理围栏越界或心跳超时后，延迟等待子女响应，超时自动触发邻里广播
/// </summary>
public class AutoRescueService : IAutoRescueService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<AutoRescueService> _logger;
    private readonly int _delayMinutes;
    private readonly bool _enabled;

    public AutoRescueService(
        IServiceScopeFactory scopeFactory,
        ILogger<AutoRescueService> logger,
        IConfiguration configuration)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _delayMinutes = configuration.GetValue("AutoRescue:DelayMinutes", AppConstants.AutoRescue.DefaultDelayMinutes);
        _enabled = configuration.GetValue("AutoRescue:Enabled", true);
    }

    /// <inheritdoc />
    public async Task StartRescueTimerAsync(Guid elderId, Guid familyId, Guid circleId, RescueTriggerType triggerType)
    {
        if (!_enabled)
        {
            _logger.LogInformation("自动救援功能已禁用，跳过");
            return;
        }

        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // 防重复：如果该老人已有待处理的救援记录，不重复创建
        var existing = await context.AutoRescueRecords
            .AnyAsync(a => a.ElderId == elderId &&
                           a.Status == AutoRescueStatus.WaitingChildResponse);
        if (existing)
        {
            _logger.LogInformation("老人 {ElderId} 已有待处理的自动救援记录，跳过", elderId);
            return;
        }

        var record = new AutoRescueRecord
        {
            Id = Guid.NewGuid(),
            ElderId = elderId,
            FamilyId = familyId,
            CircleId = circleId,
            TriggerType = triggerType,
            Status = AutoRescueStatus.WaitingChildResponse,
            TriggeredAt = DateTime.UtcNow,
        };

        context.AutoRescueRecords.Add(record);
        await context.SaveChangesAsync();

        // 通知子女
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();
        var elder = await context.Users.FindAsync(elderId);
        var elderName = elder?.RealName ?? "老人";

        var triggerText = triggerType == RescueTriggerType.GeoFenceBreach
            ? "走出安全区域"
            : "设备长时间无响应";

        var childIds = await context.FamilyMembers
            .Where(fm => fm.FamilyId == familyId && fm.Role == UserRole.Child)
            .Select(fm => fm.UserId)
            .ToListAsync();

        if (childIds.Count > 0)
        {
            await notificationService.SendToUsersAsync(
                childIds,
                AppConstants.NotificationTypes.AutoRescueAlert,
                new
                {
                    Title = "紧急：请尽快确认老人安全",
                    Content = $"{elderName}{triggerText}，请在 {_delayMinutes} 分钟内确认安全，否则将自动通知邻里圈求助。",
                    AutoRescueId = record.Id,
                    ElderId = elderId,
                    ElderName = elderName,
                    TriggerType = triggerType.ToString(),
                    DelayMinutes = _delayMinutes,
                    AlertLevel = AppConstants.AlertLevels.Critical,
                });

            // 更新通知时间
            record.ChildNotifiedAt = DateTime.UtcNow;
            await context.SaveChangesAsync();
        }

        _logger.LogInformation(
            "自动救援计时器已启动：老人={ElderId}, 触发类型={TriggerType}, 延迟={Delay}分钟",
            elderId, triggerType, _delayMinutes);
    }

    /// <inheritdoc />
    public async Task CheckPendingRescuesAsync()
    {
        if (!_enabled) return;

        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        var cutoff = DateTime.UtcNow.AddMinutes(-_delayMinutes);

        // 查找超时未响应的记录
        var pendingRecords = await context.AutoRescueRecords
            .AsTracking()
            .Include(a => a.Elder)
            .Where(a => a.Status == AutoRescueStatus.WaitingChildResponse && a.TriggeredAt < cutoff)
            .ToListAsync();

        if (pendingRecords.Count == 0) return;

        foreach (var record in pendingRecords)
        {
            // 检查子女是否已读通知（查 NotificationRecord 的 IsRead）
            var hasRead = await context.NotificationRecords
                .AnyAsync(n => n.Type == AppConstants.NotificationTypes.AutoRescueAlert &&
                               context.FamilyMembers
                                   .Where(fm => fm.FamilyId == record.FamilyId && fm.Role == UserRole.Child)
                                   .Select(fm => fm.UserId)
                                   .Contains(n.UserId) &&
                               n.IsRead);

            // 更简洁的检查：查该救援关联的通知是否有子女已读
            var childIds = await context.FamilyMembers
                .Where(fm => fm.FamilyId == record.FamilyId && fm.Role == UserRole.Child)
                .Select(fm => fm.UserId)
                .ToListAsync();

            var anyChildRead = await context.NotificationRecords
                .Where(n => n.Type == AppConstants.NotificationTypes.AutoRescueAlert &&
                            childIds.Contains(n.UserId) &&
                            n.CreatedAt >= record.TriggeredAt &&
                            n.IsRead)
                .AnyAsync();

            if (anyChildRead)
            {
                // 子女已响应，标记为已响应
                record.Status = AutoRescueStatus.ChildResponded;
                record.ChildRespondedAt = DateTime.UtcNow;
                _logger.LogInformation("自动救援记录 {RecordId}：子女已响应", record.Id);
                continue;
            }

            // 超时未响应，触发邻里广播
            record.Status = AutoRescueStatus.NeighborBroadcast;
            record.BroadcastAt = DateTime.UtcNow;

            // 创建紧急呼叫以触发邻里广播
            var emergencyService = scope.ServiceProvider.GetRequiredService<IEmergencyService>();
            var helpService = scope.ServiceProvider.GetRequiredService<INeighborHelpService>();

            var elderName = record.Elder?.RealName ?? "老人";
            _logger.LogWarning(
                "自动救援：老人 {ElderId} 的子女 {_Delay} 分钟内未响应，触发邻里圈广播",
                record.ElderId, _delayMinutes);

            // 通知子女：已自动通知邻里圈
            if (childIds.Count > 0)
            {
                await notificationService.SendToUsersAsync(
                    childIds,
                    AppConstants.NotificationTypes.AutoRescueBroadcast,
                    new
                    {
                        Title = "已自动通知邻里圈",
                        Content = $"{elderName}的告警您未及时确认，已自动通知邻里圈求助。",
                        AutoRescueId = record.Id,
                        ElderId = record.ElderId,
                        ElderName = elderName,
                    });
            }
        }

        await context.SaveChangesAsync();
    }

    /// <inheritdoc />
    public async Task ChildRespondAsync(Guid recordId, Guid childId)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var record = await context.AutoRescueRecords
            .AsTracking()
            .FirstOrDefaultAsync(a => a.Id == recordId)
            ?? throw new KeyNotFoundException(ErrorMessages.AutoRescue.RecordNotFound);

        if (record.Status != AutoRescueStatus.WaitingChildResponse)
            throw new InvalidOperationException(ErrorMessages.AutoRescue.InvalidStatusToRespond);

        // 验证操作者是该家庭的子女
        var isChild = await context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == record.FamilyId &&
                            fm.UserId == childId &&
                            fm.Role == UserRole.Child);
        if (!isChild)
            throw new UnauthorizedAccessException(ErrorMessages.AutoRescue.OnlyChildCanRespond);

        record.Status = AutoRescueStatus.ChildResponded;
        record.ChildRespondedAt = DateTime.UtcNow;
        await context.SaveChangesAsync();

        _logger.LogInformation("自动救援记录 {RecordId}：子女 {ChildId} 已主动响应", recordId, childId);
    }

    /// <inheritdoc />
    public async Task<List<AutoRescueRecord>> GetHistoryAsync(Guid familyId, int skip = 0, int limit = 20)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        return await context.AutoRescueRecords
            .Include(a => a.Elder)
            .Where(a => a.FamilyId == familyId)
            .OrderByDescending(a => a.TriggeredAt)
            .Skip(skip)
            .Take(limit)
            .ToListAsync();
    }
}
