using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
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
    Task SendToUserAsync(Guid userId, string type, object data, CancellationToken cancellationToken = default);

    /// <summary>
    /// 批量向多个用户发送同一类型通知（一次数据库写入，避免循环中的 N+1 问题）
    /// </summary>
    Task SendToUsersAsync(IEnumerable<Guid> userIds, string type, object data, CancellationToken cancellationToken = default);

    /// <summary>
    /// 向家庭成员发送通知
    /// </summary>
    Task SendToFamilyAsync(Guid familyId, string type, object data, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取用户通知列表（分页）
    /// </summary>
    Task<PagedResult<NotificationResponse>> GetUserNotificationsAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取未读通知数量
    /// </summary>
    Task<int> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 标记单条通知已读
    /// </summary>
    Task<bool> MarkAsReadAsync(Guid notificationId, Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 全部标记已读
    /// </summary>
    Task MarkAllAsReadAsync(Guid userId, CancellationToken cancellationToken = default);
}