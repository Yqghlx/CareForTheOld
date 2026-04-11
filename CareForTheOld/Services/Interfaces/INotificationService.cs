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
}