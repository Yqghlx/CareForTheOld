using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 通知服务实现
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

    public async Task SendToUserAsync(Guid userId, string type, object data)
    {
        // 通过 SignalR 实时推送
        await _hubContext.Clients.Group($"user_{userId}")
            .SendAsync("ReceiveNotification", type, data);

        // 持久化通知记录
        var dict = JsonSerializer.Deserialize<Dictionary<string, object>>(
            JsonSerializer.Serialize(data));

        var record = new NotificationRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = type,
            Title = dict?.GetValueOrDefault("Title")?.ToString() ?? "通知",
            Content = dict?.GetValueOrDefault("Content")?.ToString() ?? "",
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        };

        _context.NotificationRecords.Add(record);
        await _context.SaveChangesAsync();
    }

    public async Task SendToFamilyAsync(Guid familyId, string type, object data)
    {
        await _hubContext.Clients.Group($"family_{familyId}")
            .SendAsync("ReceiveNotification", type, data);
    }
}
