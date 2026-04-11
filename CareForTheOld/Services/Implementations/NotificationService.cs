using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.SignalR;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 通知服务实现
/// </summary>
public class NotificationService : INotificationService
{
    private readonly IHubContext<NotificationHub> _hubContext;

    public NotificationService(IHubContext<NotificationHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public async Task SendToUserAsync(Guid userId, string type, object data)
    {
        await _hubContext.Clients.Group($"user_{userId}")
            .SendAsync("ReceiveNotification", type, data);
    }

    public async Task SendToFamilyAsync(Guid familyId, string type, object data)
    {
        await _hubContext.Clients.Group($"family_{familyId}")
            .SendAsync("ReceiveNotification", type, data);
    }
}