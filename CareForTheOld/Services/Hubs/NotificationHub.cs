using System.Collections.Concurrent;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace CareForTheOld.Services.Hubs;

/// <summary>
/// 通知推送中心（需认证）
///
/// 支持心跳检测机制：前端定期调用 Heartbeat 方法更新最后活跃时间，
/// 后台 HeartbeatMonitorService 检测长时间无心跳的老人并触发离线告警。
/// </summary>
[Authorize]
public class NotificationHub : Hub
{
    private readonly ILogger<NotificationHub> _logger;

    /// <summary>
    /// 在线连接追踪：UserId → ConnectionId 集合
    /// 用于统计在线用户数和调试
    /// </summary>
    private static readonly ConcurrentDictionary<string, HashSet<string>> _onlineUsers = new();

    /// <summary>
    /// 用户最后活跃时间：UserId → 最后心跳时间
    /// 用于离线检测，区分"已断开"和"已连接但长时间无响应"
    /// </summary>
    private static readonly ConcurrentDictionary<string, DateTime> _lastHeartbeat = new();

    /// <summary>当前在线用户数</summary>
    public static int OnlineUserCount => _onlineUsers.Count;

    /// <summary>当前总连接数</summary>
    public static int TotalConnectionCount => _onlineUsers.Values.Sum(c => c.Count);

    /// <summary>
    /// 获取所有在线用户的最后活跃时间（快照）
    /// 供 HeartbeatMonitorService 使用
    /// </summary>
    public static IReadOnlyDictionary<string, DateTime> LastHeartbeats => _lastHeartbeat;

    public NotificationHub(ILogger<NotificationHub> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// 用户连接时，加入个人组（需已认证）
    /// </summary>
    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        if (string.IsNullOrEmpty(userId))
        {
            // 未认证用户直接拒绝连接
            Context.Abort();
            return;
        }

        // 记录在线连接
        _onlineUsers.AddOrUpdate(
            userId,
            _ => new HashSet<string> { Context.ConnectionId },
            (_, connections) => { lock (connections) { connections.Add(Context.ConnectionId); } return connections; });

        // 记录连接时间作为初始心跳
        _lastHeartbeat[userId] = DateTime.UtcNow;

        await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");

        _logger.LogInformation("SignalR 连接: 用户 {UserId}, 连接ID {ConnectionId}, 在线用户 {OnlineCount}, 总连接 {TotalCount}",
            userId, Context.ConnectionId, OnlineUserCount, TotalConnectionCount);

        await base.OnConnectedAsync();
    }

    /// <summary>
    /// 用户断开连接时，移出个人组
    /// </summary>
    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = Context.UserIdentifier;
        if (!string.IsNullOrEmpty(userId))
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"user_{userId}");

            // 清理在线连接记录
            if (_onlineUsers.TryGetValue(userId, out var connections))
            {
                lock (connections)
                {
                    connections.Remove(Context.ConnectionId);
                }
                if (connections.Count == 0)
                {
                    _onlineUsers.TryRemove(userId, out _);
                    // 用户完全离线时清理心跳记录
                    _lastHeartbeat.TryRemove(userId, out _);
                }
            }

            if (exception != null)
            {
                _logger.LogWarning(exception, "SignalR 异常断开: 用户 {UserId}, 连接ID {ConnectionId}",
                    userId, Context.ConnectionId);
            }
            else
            {
                _logger.LogInformation("SignalR 断开: 用户 {UserId}, 连接ID {ConnectionId}, 在线用户 {OnlineCount}",
                    userId, Context.ConnectionId, OnlineUserCount);
            }
        }

        await base.OnDisconnectedAsync(exception);
    }

    /// <summary>
    /// 心跳方法（前端定期调用，建议每 60 秒一次）
    ///
    /// 更新用户最后活跃时间。当后台服务检测到老人端超过阈值
    /// 未发送心跳时，自动触发离线告警通知子女。
    /// </summary>
    public async Task Heartbeat()
    {
        var userId = Context.UserIdentifier;
        if (string.IsNullOrEmpty(userId)) return;

        _lastHeartbeat[userId] = DateTime.UtcNow;
        _logger.LogDebug("心跳: 用户 {UserId}", userId);

        await Task.CompletedTask;
    }

    /// <summary>
    /// 加入家庭组（用于家庭内部消息）
    /// </summary>
    public async Task JoinFamilyGroup(Guid familyId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"family_{familyId}");
        _logger.LogDebug("用户 {UserId} 加入家庭组 {FamilyId}", Context.UserIdentifier, familyId);
    }

    /// <summary>
    /// 离开家庭组
    /// </summary>
    public async Task LeaveFamilyGroup(Guid familyId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"family_{familyId}");
        _logger.LogDebug("用户 {UserId} 离开家庭组 {FamilyId}", Context.UserIdentifier, familyId);
    }
}
