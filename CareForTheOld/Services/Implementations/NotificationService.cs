using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
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
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(IHubContext<NotificationHub> hubContext, AppDbContext context, ILogger<NotificationService> logger)
    {
        _hubContext = hubContext;
        _context = context;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task SendToUserAsync(Guid userId, string type, object data, CancellationToken cancellationToken = default)
    {
        var (title, content, payload) = ExtractNotificationData(data);

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
            Payload = payload,
            Status = OutboxStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        _context.NotificationOutboxes.Add(outbox);

        // 同一事务中写入两张表，确保数据一致性
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogDebug("通知已写入：用户 {UserId}，类型 {Type}", userId, type);
    }

    /// <inheritdoc />
    public async Task SendToUsersAsync(IEnumerable<Guid> userIds, string type, object data, CancellationToken cancellationToken = default)
    {
        var (title, content, payload) = ExtractNotificationData(data);
        var now = DateTime.UtcNow;

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
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogDebug("批量通知已写入：{Count} 个用户，类型 {Type}", userIds.Count(), type);
    }

    /// <inheritdoc />
    public async Task SendToFamilyAsync(Guid familyId, string type, object data, CancellationToken cancellationToken = default)
    {
        await _hubContext.Clients.Group(AppConstants.SignalRGroups.FamilyGroupName(familyId))
            .SendAsync(AppConstants.SignalRMethods.ReceiveNotification, type, data, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<PagedResult<NotificationResponse>> GetUserNotificationsAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default)
    {
        limit = Math.Clamp(limit, AppConstants.Pagination.MinPageSize, AppConstants.Pagination.MaxPageSize);

        var totalCount = await _context.NotificationRecords
            .CountAsync(n => n.UserId == userId, cancellationToken);

        var items = await _context.NotificationRecords
            .Where(n => n.UserId == userId)
            .OrderByDescending(n => n.CreatedAt)
            .Skip(skip)
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
            .ToListAsync(cancellationToken);

        return new PagedResult<NotificationResponse>
        {
            Items = items,
            TotalCount = totalCount,
            Skip = skip,
            Limit = limit
        };
    }

    /// <inheritdoc />
    public async Task<int> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.NotificationRecords
            .CountAsync(n => n.UserId == userId && !n.IsRead, cancellationToken);
    }

    /// <inheritdoc />
    public async Task<bool> MarkAsReadAsync(Guid notificationId, Guid userId, CancellationToken cancellationToken = default)
    {
        var notification = await _context.NotificationRecords
            .AsTracking()
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.UserId == userId, cancellationToken);

        if (notification == null) return false;

        notification.IsRead = true;
        await _context.SaveChangesAsync(cancellationToken);
        return true;
    }

    /// <inheritdoc />
    public async Task MarkAllAsReadAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var unreadNotifications = await _context.NotificationRecords
            .AsTracking()
            .Where(n => n.UserId == userId && !n.IsRead)
            .ToListAsync(cancellationToken);

        foreach (var notification in unreadNotifications)
        {
            notification.IsRead = true;
        }

        await _context.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// 从匿名对象中提取通知标题、内容和完整 JSON 载荷
    /// </summary>
    private static (string title, string content, string payload) ExtractNotificationData(object data)
    {
        var payload = JsonSerializer.Serialize(data);
        var dict = JsonSerializer.Deserialize<Dictionary<string, object>>(payload);

        var title = dict?.GetValueOrDefault("Title")?.ToString() ?? NotificationMessages.DefaultTitle;
        var content = dict?.GetValueOrDefault("Content")?.ToString() ?? "";
        return (title, content, payload);
    }
}
