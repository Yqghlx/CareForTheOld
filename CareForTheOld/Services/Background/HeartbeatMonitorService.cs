using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using Hangfire;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.Collections.Concurrent;

namespace CareForTheOld.Services.Background;

/// <summary>
/// 心跳监控服务
///
/// 定期检查在线老人用户的心跳状态。当检测到老人端超过阈值时间
/// 未发送心跳时，自动触发离线告警通知子女。
///
/// 检测逻辑：
/// 1. 遍历所有在线用户（SignalR 连接存在）
/// 2. 检查最后心跳时间是否超过阈值（默认 5 分钟）
/// 3. 确认用户角色为老人
/// 4. 发送离线告警通知给同一家庭的子女成员
///
/// 为避免重复告警，每条告警间隔至少 15 分钟。
/// </summary>
public class HeartbeatMonitorService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<HeartbeatMonitorService> _logger;

    /// <summary>
    /// 心跳超时阈值（超过此时间无心跳视为离线）
    /// </summary>
    private readonly TimeSpan _heartbeatTimeout;

    /// <summary>
    /// 告警冷却时间（同一用户两次告警的最小间隔）
    /// </summary>
    private readonly TimeSpan _alertCooldown;

    /// <summary>
    /// 最近一次告警时间：UserId → 上次告警时间
    /// 使用 ConcurrentDictionary 防止多线程并发访问异常
    /// </summary>
    private static readonly ConcurrentDictionary<string, DateTime> _lastAlertTime = new();

    public HeartbeatMonitorService(
        IServiceScopeFactory scopeFactory,
        ILogger<HeartbeatMonitorService> logger,
        IConfiguration configuration)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _heartbeatTimeout = TimeSpan.FromMinutes(
            configuration.GetValue(ConfigurationKeys.Heartbeat.TimeoutMinutes, AppConstants.Heartbeat.DefaultTimeoutMinutes));
        _alertCooldown = TimeSpan.FromMinutes(
            configuration.GetValue(ConfigurationKeys.Heartbeat.AlertCooldownMinutes, AppConstants.Heartbeat.DefaultAlertCooldownMinutes));
    }

    /// <summary>
    /// Hangfire RecurringJob 入口方法（每分钟执行一次）
    /// </summary>
    // 重试策略参考 AppConstants.HangfireRetry
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = new[] { 10, 30 })]
    public async Task CheckHeartbeatsAsync()
    {
        var heartbeats = NotificationHub.LastHeartbeats;
        if (!heartbeats.Any()) return;

        var now = DateTime.UtcNow;

        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        // 筛选出超时且需要告警的用户
        var timeoutUserIds = new List<(string userIdStr, Guid userId, TimeSpan elapsed)>();
        foreach (var (userIdStr, lastHeartbeat) in heartbeats)
        {
            var elapsed = now - lastHeartbeat;
            if (elapsed <= _heartbeatTimeout) continue;

            if (_lastAlertTime.TryGetValue(userIdStr, out var lastAlert) && now - lastAlert < _alertCooldown)
                continue;

            if (!Guid.TryParse(userIdStr, out var userId)) continue;

            timeoutUserIds.Add((userIdStr, userId, elapsed));
        }

        if (!timeoutUserIds.Any()) return;

        // 批量预加载用户信息（避免循环内 N+1 查询）
        var userIds = timeoutUserIds.Select(t => t.userId).ToHashSet();
        var users = await context.Users
            .Where(u => userIds.Contains(u.Id) && u.Role == UserRole.Elder)
            .ToDictionaryAsync(u => u.Id, u => u);

        // 批量预加载家庭成员关系
        var elderFamilyMembers = await context.FamilyMembers
            .Where(fm => userIds.Contains(fm.UserId))
            .ToDictionaryAsync(fm => fm.UserId, fm => fm);

        // 批量预加载子女信息
        var familyIds = elderFamilyMembers.Values.Select(fm => fm.FamilyId).Distinct().ToHashSet();
        var childrenByFamily = await context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => familyIds.Contains(fm.FamilyId) && fm.Role == UserRole.Child)
            .GroupBy(fm => fm.FamilyId)
            .ToDictionaryAsync(g => g.Key, g => g.ToList());

        // 批量预加载邻里圈成员关系（自动救援用）
        var circleMemberships = await context.NeighborCircleMembers
            .Where(m => userIds.Contains(m.UserId))
            .ToDictionaryAsync(m => m.UserId, m => m);

        foreach (var (userIdStr, userId, elapsed) in timeoutUserIds)
        {
            // 检查用户是否存在且为老人角色
            if (!users.TryGetValue(userId, out var user)) continue;

            if (!elderFamilyMembers.TryGetValue(userId, out var familyMember)) continue;

            if (!childrenByFamily.TryGetValue(familyMember.FamilyId, out var children) || !children.Any()) continue;

            var offlineMinutes = (int)elapsed.TotalMinutes;

            _logger.LogWarning("[心跳监控] 老人 {Name}({UserId}) 已 {Minutes} 分钟无心跳，触发离线告警",
                user.RealName, userId, offlineMinutes);

            await notificationService.SendToUsersAsync(
                children.Select(c => c.UserId),
                AppConstants.NotificationTypes.ElderOffline,
                new
                {
                    Title = NotificationMessages.Heartbeat.OfflineTitle,
                    Content = string.Format(NotificationMessages.Heartbeat.OfflineContentTemplate, user.RealName, offlineMinutes),
                    ElderId = userId,
                    ElderName = user.RealName,
                    OfflineMinutes = offlineMinutes,
                    LastHeartbeat = now - elapsed,
                    AlertLevel = AppConstants.AlertLevels.Critical
                }
            );

            // 检查老人是否在邻里圈中，若在则启动自动救援计时器
            if (circleMemberships.TryGetValue(userId, out var circleMembership))
            {
                try
                {
                    var autoRescueService = scope.ServiceProvider.GetRequiredService<IAutoRescueService>();
                    await autoRescueService.StartRescueTimerAsync(
                        userId, familyMember.FamilyId, circleMembership.CircleId,
                        RescueTriggerType.HeartbeatTimeout);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "启动自动救援计时器失败，老人 {UserId}", userId);
                }
            }

            // 记录告警时间
            _lastAlertTime[userIdStr] = now;
        }

        // 清理已离线用户的告警记录，防止内存泄漏
        var offlineUsers = _lastAlertTime.Keys
            .Where(k => !heartbeats.ContainsKey(k))
            .ToList();
        foreach (var key in offlineUsers)
        {
            _lastAlertTime.TryRemove(key, out _);
        }
    }
}
