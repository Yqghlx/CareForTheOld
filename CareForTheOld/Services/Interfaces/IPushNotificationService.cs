namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 推送通知服务接口
///
/// 通过 FCM 向用户设备发送推送通知。
/// 用于 APP 在后台或关闭时仍能收到紧急呼叫等关键通知。
/// </summary>
public interface IPushNotificationService
{
    /// <summary>
    /// 向单个用户的所有设备发送推送通知
    /// </summary>
    /// <returns>是否全部推送成功</returns>
    Task<bool> SendAsync(Guid userId, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// 向多个用户的所有设备批量发送推送通知
    /// </summary>
    /// <returns>是否全部推送成功</returns>
    Task<bool> SendAsync(IEnumerable<Guid> userIds, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default);
}
