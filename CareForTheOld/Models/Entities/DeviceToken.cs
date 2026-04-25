namespace CareForTheOld.Models.Entities;

/// <summary>
/// 设备推送令牌实体
///
/// 存储用户的 FCM 设备令牌，用于推送通知。
/// 一个用户可以有多个设备（手机、平板），每个设备有唯一的 FCM token。
/// 登录时注册/更新 token，登出时清除。
/// </summary>
public class DeviceToken
{
    public Guid Id { get; set; }

    /// <summary>
    /// 关联用户 ID
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// FCM 设备令牌（由客户端 Firebase Messaging 生成）
    /// </summary>
    public string Token { get; set; } = string.Empty;

    /// <summary>
    /// 平台标识（"android" / "ios"）
    /// </summary>
    public string Platform { get; set; } = "android";

    /// <summary>
    /// 首次注册时间
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 最后活跃时间（每次登录时刷新，用于清理过期 token）
    /// </summary>
    public DateTime LastActiveAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public User User { get; set; } = null!;
}
