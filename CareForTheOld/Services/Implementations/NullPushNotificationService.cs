using CareForTheOld.Services.Interfaces;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 空推送通知服务（开发环境回退）
///
/// 当未配置 Firebase 凭据时使用此实现，所有推送操作静默跳过。
/// 避免开发环境因缺少 Firebase 配置而启动失败。
/// </summary>
public class NullPushNotificationService : IPushNotificationService
{
    private readonly ILogger<NullPushNotificationService> _logger;

    public NullPushNotificationService(ILogger<NullPushNotificationService> logger)
    {
        _logger = logger;
    }

    public Task<bool> SendAsync(Guid userId, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("推送通知已跳过（未配置 FCM），目标用户: {UserId}", userId);
        return Task.FromResult(false);
    }

    public Task<bool> SendAsync(IEnumerable<Guid> userIds, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("推送通知已跳过（未配置 FCM），目标用户数: {Count}", userIds.Count());
        return Task.FromResult(false);
    }
}
