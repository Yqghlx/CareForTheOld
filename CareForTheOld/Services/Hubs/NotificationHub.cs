using Microsoft.AspNetCore.SignalR;

namespace CareForTheOld.Services.Hubs;

/// <summary>
/// 通知推送中心
/// </summary>
public class NotificationHub : Hub
{
    /// <summary>
    /// 用户连接时，加入个人组
    /// </summary>
    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        if (!string.IsNullOrEmpty(userId))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");
        }
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
        }
        await base.OnDisconnectedAsync(exception);
    }

    /// <summary>
    /// 加入家庭组（用于家庭内部消息）
    /// </summary>
    public async Task JoinFamilyGroup(Guid familyId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"family_{familyId}");
    }

    /// <summary>
    /// 离开家庭组
    /// </summary>
    public async Task LeaveFamilyGroup(Guid familyId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"family_{familyId}");
    }
}