namespace CareForTheOld.Models.Entities;

/// <summary>
/// 通知发件箱实体（Outbox Pattern）
///
/// 确保数据库变更与 SignalR 通知发送的最终一致性。
/// 业务操作与通知写入在同一事务中完成，由后台 Job 异步投递 SignalR 消息，
/// 避免 SignalR 发送失败导致业务数据已提交但用户未收到通知的问题。
/// </summary>
public class NotificationOutbox
{
    public Guid Id { get; set; }

    /// <summary>
    /// 接收用户 ID
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// 通知类型（如 MedicationReminder、GeoFenceAlert、HealthAlert 等）
    /// </summary>
    public string Type { get; set; } = string.Empty;

    /// <summary>
    /// 通知标题
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// 通知内容
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// 附加数据的 JSON 序列化（用于 SignalR 推送）
    /// </summary>
    public string? Payload { get; set; }

    /// <summary>
    /// 投递状态：Pending=待投递，Sent=已投递，Failed=投递失败
    /// </summary>
    public OutboxStatus Status { get; set; } = OutboxStatus.Pending;

    /// <summary>
    /// 重试次数（最多 5 次）
    /// </summary>
    public int RetryCount { get; set; }

    /// <summary>
    /// 最近一次失败原因
    /// </summary>
    public string? LastError { get; set; }

    /// <summary>
    /// 创建时间
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 投递成功时间
    /// </summary>
    public DateTime? SentAt { get; set; }
}

/// <summary>
/// Outbox 投递状态
/// </summary>
public enum OutboxStatus
{
    /// <summary>待投递</summary>
    Pending = 0,
    /// <summary>已投递</summary>
    Sent = 1,
    /// <summary>投递失败（超过最大重试次数）</summary>
    Failed = 2
}
