using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using Hangfire;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace CareForTheOld.Services.Background;

/// <summary>
/// Outbox 投递后台服务
///
/// 定期从 NotificationOutbox 表读取 Pending 状态的消息，
/// 通过 SignalR 推送给用户，成功后标记为 Sent。
/// 失败时增加重试计数，超过 5 次标记为 Failed。
/// 使用独立的 ServiceProvider Scope 避免 DbContext 生命周期问题。
/// </summary>
public class OutboxDispatchService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<OutboxDispatchService> _logger;

    public OutboxDispatchService(IServiceScopeFactory scopeFactory, ILogger<OutboxDispatchService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    /// <summary>
    /// Hangfire RecurringJob 入口方法
    /// </summary>
    // 重试策略参考 AppConstants.HangfireRetry
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = new[] { 10, 30 })]
    public async Task DispatchOutboxMessagesAsync(CancellationToken cancellationToken = default)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<NotificationHub>>();

        // 查询待投递的消息（按创建时间排序，先投递最早的）
        var pendingMessages = await context.NotificationOutboxes
            .Where(o => o.Status == OutboxStatus.Pending && o.RetryCount < AppConstants.Outbox.MaxRetries)
            .OrderBy(o => o.CreatedAt)
            .Take(AppConstants.Outbox.BatchSize)
            .AsTracking()
            .ToListAsync(cancellationToken);

        if (!pendingMessages.Any()) return;

        _logger.LogDebug("[Outbox] 开始投递 {Count} 条待发送通知", pendingMessages.Count);

        var successCount = 0;
        var failCount = 0;

        foreach (var message in pendingMessages)
        {
            try
            {
                // 反序列化完整数据用于 SignalR 推送
                object? data = string.IsNullOrEmpty(message.Payload)
                    ? null
                    : JsonSerializer.Deserialize<object>(message.Payload);

                // 通过 SignalR 推送
                await hubContext.Clients.Group(AppConstants.SignalRGroups.UserGroupName(message.UserId))
                    .SendAsync(AppConstants.SignalRMethods.ReceiveNotification, message.Type, data, cancellationToken);

                // 标记为已投递
                message.Status = OutboxStatus.Sent;
                message.SentAt = DateTime.UtcNow;
                successCount++;
            }
            catch (Exception ex)
            {
                message.RetryCount++;
                message.LastError = ex.Message;

                if (message.RetryCount >= AppConstants.Outbox.MaxRetries)
                {
                    // 超过最大重试次数，标记为失败
                    message.Status = OutboxStatus.Failed;
                    _logger.LogWarning("[Outbox] 通知 {Id} 投递失败（已重试 {Retries} 次）：{Error}",
                        message.Id, message.RetryCount, ex.Message);
                }

                failCount++;
            }
        }

        await context.SaveChangesAsync(cancellationToken);

        if (successCount > 0 || failCount > 0)
        {
            _logger.LogInformation("[Outbox] 投递完成：成功 {Success}，失败 {Fail}", successCount, failCount);
        }
    }
}
