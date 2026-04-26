using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 通知服务实现（Outbox Pattern）
///
/// SendToUserAsync 将通知同时写入 NotificationRecord（供查询）和 NotificationOutbox（供投递），
/// 由后台 OutboxDispatchService 异步通过 SignalR 推送，确保数据库变更与通知的最终一致性。
/// </summary>
public class NotificationService : INotificationService
{
    private readonly IHubContext<NotificationHub> _hubContext;
    private readonly AppDbContext _context;

    public NotificationService(IHubContext<NotificationHub> hubContext, AppDbContext context)
    {
        _hubContext = hubContext;
        _context = context;
    }

    /// <summary>
    /// 向单个用户发送通知（Outbox Pattern 写入）
    /// </summary>
    public async Task SendToUserAsync(Guid userId, string type, object data)
    {
        // 解析通知数据
        var dict = JsonSerializer.Deserialize<Dictionary<string, object>>(
            JsonSerializer.Serialize(data));

        var title = dict?.GetValueOrDefault("Title")?.ToString() ?? NotificationMessages.DefaultTitle;
        var content = dict?.GetValueOrDefault("Content")?.ToString() ?? "";

        // 写入通知记录（供用户查询历史通知）
        var record = new NotificationRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = type,
            Title = title,
            Content = content,
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        };
        _context.NotificationRecords.Add(record);

        // 写入 Outbox 表（供后台 Job 异步投递 SignalR 消息）
        var outbox = new NotificationOutbox
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = type,
            Title = title,
            Content = content,
            Payload = JsonSerializer.Serialize(data),
            Status = OutboxStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        _context.NotificationOutboxes.Add(outbox);

        // 同一事务中写入两张表，确保数据一致性
        await _context.SaveChangesAsync();
    }

    /// <inheritdoc />
    public async Task SendToUsersAsync(IEnumerable<Guid> userIds, string type, object data)
    {
        var dict = JsonSerializer.Deserialize<Dictionary<string, object>>(
            JsonSerializer.Serialize(data));

        var title = dict?.GetValueOrDefault("Title")?.ToString() ?? NotificationMessages.DefaultTitle;
        var content = dict?.GetValueOrDefault("Content")?.ToString() ?? "";
        var now = DateTime.UtcNow;
        var payload = JsonSerializer.Serialize(data);

        foreach (var userId in userIds)
        {
            _context.NotificationRecords.Add(new NotificationRecord
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = type,
                Title = title,
                Content = content,
                IsRead = false,
                CreatedAt = now
            });

            _context.NotificationOutboxes.Add(new NotificationOutbox
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = type,
                Title = title,
                Content = content,
                Payload = payload,
                Status = OutboxStatus.Pending,
                CreatedAt = now
            });
        }

        // 所有记录一次写入，避免循环中多次 SaveChanges 的 N+1 问题
        await _context.SaveChangesAsync();
    }

    /// <summary>
    /// 向家庭所有成员发送通知
    /// </summary>
    public async Task SendToFamilyAsync(Guid familyId, string type, object data)
    {
        await _hubContext.Clients.Group(AppConstants.SignalRGroups.FamilyGroupName(familyId))
            .SendAsync("ReceiveNotification", type, data);
    }

    /// <summary>
    /// 获取用户通知列表（分页）
    /// </summary>
    public async Task<List<NotificationResponse>> GetUserNotificationsAsync(Guid userId, int limit = AppConstants.Pagination.DefaultPageSize)
    {
        limit = Math.Clamp(limit, AppConstants.Pagination.MinPageSize, AppConstants.Pagination.MaxPageSize);
        return await _context.NotificationRecords
            .Where(n => n.UserId == userId)
            .OrderByDescending(n => n.CreatedAt)
            .Take(limit)
            .Select(n => new NotificationResponse
            {
                Id = n.Id,
                Type = n.Type,
                Title = n.Title,
                Content = n.Content,
                IsRead = n.IsRead,
                CreatedAt = n.CreatedAt
            })
            .ToListAsync();
    }

    /// <summary>
    /// 获取用户未读通知数量
    /// </summary>
    public async Task<int> GetUnreadCountAsync(Guid userId)
    {
        return await _context.NotificationRecords
            .CountAsync(n => n.UserId == userId && !n.IsRead);
    }

    /// <summary>
    /// 标记单条通知为已读
    /// </summary>
    public async Task<bool> MarkAsReadAsync(Guid notificationId, Guid userId)
    {
        var notification = await _context.NotificationRecords
            .AsTracking()
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.UserId == userId);

        if (notification == null) return false;

        notification.IsRead = true;
        await _context.SaveChangesAsync();
        return true;
    }

    /// <summary>
    /// 标记用户所有通知为已读
    /// </summary>
    public async Task MarkAllAsReadAsync(Guid userId)
    {
        var unreadNotifications = await _context.NotificationRecords
            .AsTracking()
            .Where(n => n.UserId == userId && !n.IsRead)
            .ToListAsync();

        foreach (var notification in unreadNotifications)
        {
            notification.IsRead = true;
        }

        await _context.SaveChangesAsync();
    }
}
