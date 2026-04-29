namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 设备令牌管理服务接口
///
/// 管理用户设备的 FCM 推送令牌注册、更新和清除。
/// </summary>
public interface IDeviceService
{
    /// <summary>
    /// 注册或刷新 FCM 设备令牌
    ///
    /// 若 token 已存在（同一设备换用户登录），则更新关联用户和活跃时间。
    /// </summary>
    Task RegisterTokenAsync(Guid userId, string token, string platform, CancellationToken cancellationToken = default);

    /// <summary>
    /// 清除指定用户的所有设备令牌（登出时调用）
    /// </summary>
    /// <returns>删除的令牌数量</returns>
    Task<int> DeleteTokensAsync(Guid userId, CancellationToken cancellationToken = default);
}
