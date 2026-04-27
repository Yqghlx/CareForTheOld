using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Services.Interfaces;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// FCM 推送通知服务实现
///
/// 通过 Firebase Cloud Messaging 向用户设备发送推送通知。
/// 用于 APP 在后台或关闭时仍能收到紧急呼叫等关键通知。
///
/// 发送流程：
/// 1. 从数据库查询目标用户的所有 FCM 设备 token
/// 2. 构建 multicast message（最多 500 个 token/批次）
/// 3. 调用 FCM API 批量发送
/// 4. 清理无效 token（FCM 返回未注册/过期的 token 时自动从数据库删除）
/// </summary>
public class FcmPushNotificationService : IPushNotificationService
{
    private readonly AppDbContext _context;
    private readonly ILogger<FcmPushNotificationService> _logger;

    public FcmPushNotificationService(
        AppDbContext context,
        ILogger<FcmPushNotificationService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<bool> SendAsync(Guid userId, string title, string body, Dictionary<string, string>? data = null)
    {
        return await SendAsync(new[] { userId }, title, body, data);
    }

    /// <inheritdoc />
    public async Task<bool> SendAsync(IEnumerable<Guid> userIds, string title, string body, Dictionary<string, string>? data = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(title, nameof(title));
        ArgumentException.ThrowIfNullOrWhiteSpace(body, nameof(body));

        var userIdList = userIds.ToList();
        if (!userIdList.Any()) return true;

        // 查询目标用户的所有设备 token
        var tokens = await _context.DeviceTokens
            .Where(dt => userIdList.Contains(dt.UserId))
            .Select(dt => dt.Token)
            .ToListAsync();

        if (!tokens.Any())
        {
            _logger.LogDebug("无设备 token 可推送，目标用户数: {Count}", userIdList.Count);
            return false;
        }

        // FCM multicast 最多 500 token/批次
        var batches = tokens.Chunk(AppConstants.Fcm.MaxBatchSize);
        var allSuccess = true;

        foreach (var batch in batches)
        {
            var success = await SendBatchAsync(batch.ToList(), title, body, data);
            if (!success) allSuccess = false;
        }

        return allSuccess;
    }

    /// <summary>
    /// 发送一批 FCM 推送消息
    /// </summary>
    private async Task<bool> SendBatchAsync(List<string> tokens, string title, string body, Dictionary<string, string>? data)
    {
        try
        {
            var message = new MulticastMessage
            {
                Tokens = tokens,
                Notification = new FirebaseAdmin.Messaging.Notification
                {
                    Title = title,
                    Body = body,
                },
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        ChannelId = AppConstants.NotificationChannels.Emergency,
                        Priority = NotificationPriority.HIGH,
                        DefaultSound = true,
                        // 锁屏可见
                        Visibility = NotificationVisibility.PUBLIC,
                    },
                },
                Data = data ?? new Dictionary<string, string>(),
            };

            var response = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(message);

            _logger.LogInformation(
                "FCM 推送完成: 总数={Total}, 成功={Success}, 失败={Failure}",
                response.Responses.Count, response.SuccessCount, response.FailureCount);

            // 清理无效 token
            if (response.FailureCount > 0)
            {
                await CleanupInvalidTokensAsync(tokens, response.Responses);
            }

            return response.FailureCount == 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FCM 推送发送异常，token 数: {Count}", tokens.Count);
            return false;
        }
    }

    /// <summary>
    /// 清理 FCM 返回的无效 token（未注册/过期）
    /// </summary>
    private async Task CleanupInvalidTokensAsync(
        List<string> tokens,
        IReadOnlyList<SendResponse> responses)
    {
        var invalidTokens = new List<string>();

        for (var i = 0; i < responses.Count; i++)
        {
            if (!responses[i].IsSuccess)
            {
                var errorCode = responses[i].Exception.MessagingErrorCode;
                // 未注册或无效的 token 需要清理
                if (errorCode == MessagingErrorCode.Unregistered ||
                    errorCode == MessagingErrorCode.InvalidArgument)
                {
                    invalidTokens.Add(tokens[i]);
                }
            }
        }

        if (invalidTokens.Any())
        {
            var deleted = await _context.DeviceTokens
                .Where(dt => invalidTokens.Contains(dt.Token))
                .ExecuteDeleteAsync();

            if (deleted > 0)
            {
                _logger.LogInformation("已清理 {Count} 个无效 FCM token", deleted);
            }
        }
    }
}
