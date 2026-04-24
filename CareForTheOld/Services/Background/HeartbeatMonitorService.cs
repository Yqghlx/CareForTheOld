using CareForTheOld.Data;
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
            configuration.GetValue("Heartbeat:TimeoutMinutes", 5));
        _alertCooldown = TimeSpan.FromMinutes(
            configuration.GetValue("Heartbeat:AlertCooldownMinutes", 15));
    }

    /// <summary>
    /// Hangfire RecurringJob 入口方法（每分钟执行一次）
    /// </summary>
    public async Task CheckHeartbeatsAsync()
    {
        var heartbeats = NotificationHub.LastHeartbeats;
        if (heartbeats.Count == 0) return;

        var now = DateTime.UtcNow;

        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        foreach (var (userIdStr, lastHeartbeat) in heartbeats)
        {
            var elapsed = now - lastHeartbeat;
            if (elapsed <= _heartbeatTimeout) continue;

            // 检查告警冷却
            if (_lastAlertTime.TryGetValue(userIdStr, out var lastAlert) && now - lastAlert < _alertCooldown)
                continue;

            if (!Guid.TryParse(userIdStr, out var userId)) continue;

            // 查询用户信息
            var user = await context.Users.FindAsync(userId);
            if (user == null || user.Role != UserRole.Elder) continue;

            // 查询家庭成员（通知子女）
            var familyMember = await context.FamilyMembers
                .FirstOrDefaultAsync(fm => fm.UserId == userId);
            if (familyMember == null) continue;

            var children = await context.FamilyMembers
                .Include(fm => fm.User)
                .Where(fm => fm.FamilyId == familyMember.FamilyId && fm.Role == UserRole.Child)
                .ToListAsync();

            if (children.Count == 0) continue;

            var offlineMinutes = (int)elapsed.TotalMinutes;

            _logger.LogWarning("[心跳监控] 老人 {Name}({UserId}) 已 {Minutes} 分钟无心跳，触发离线告警",
                user.RealName, userId, offlineMinutes);

            if (children.Count > 0)
            {
                await notificationService.SendToUsersAsync(
                    children.Select(c => c.UserId),
                    "ElderOffline",
                    new
                    {
                        Title = "老人离线告警",
                        Content = $"{user.RealName} 已超过 {offlineMinutes} 分钟未响应心跳，请及时确认是否安全。",
                        ElderId = userId,
                        ElderName = user.RealName,
                        OfflineMinutes = offlineMinutes,
                        LastHeartbeat = lastHeartbeat,
                        AlertLevel = "Critical"
                    }
                );
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
