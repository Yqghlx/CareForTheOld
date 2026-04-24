namespace CareForTheOld.Models.Entities;

/// <summary>
/// 求助通知日志 — 记录每次广播通知的邻居及其响应情况，用于计算响应率
/// </summary>
public class HelpNotificationLog
{
    public Guid Id { get; set; }

    /// <summary>关联的求助请求 ID</summary>
    public Guid HelpRequestId { get; set; }

    /// <summary>被通知的邻居用户 ID</summary>
    public Guid UserId { get; set; }

    /// <summary>通知时间</summary>
    public DateTime NotifiedAt { get; set; } = DateTime.UtcNow;

    /// <summary>响应时间（null 表示未响应）</summary>
    public DateTime? RespondedAt { get; set; }

    // 导航属性
    public NeighborHelpRequest HelpRequest { get; set; } = null!;
    public User User { get; set; } = null!;
}
