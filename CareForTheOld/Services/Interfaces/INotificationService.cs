using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 通知服务接口
/// </summary>
public interface INotificationService
{
    /// <summary>
    /// 向指定用户发送通知
    /// </summary>
    Task SendToUserAsync(Guid userId, string type, object data);

    /// <summary>
    /// 向家庭成员发送通知
    /// </summary>
    Task SendToFamilyAsync(Guid familyId, string type, object data);

    /// <summary>
    /// 获取用户通知列表
    /// </summary>
    Task<List<NotificationResponse>> GetUserNotificationsAsync(Guid userId, int limit = 50);

    /// <summary>
    /// 获取未读通知数量
    /// </summary>
    Task<int> GetUnreadCountAsync(Guid userId);

    /// <summary>
    /// 标记单条通知已读
    /// </summary>
    Task<bool> MarkAsReadAsync(Guid notificationId, Guid userId);

    /// <summary>
    /// 全部标记已读
    /// </summary>
    Task MarkAllAsReadAsync(Guid userId);
}