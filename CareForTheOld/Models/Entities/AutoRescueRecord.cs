using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 自动救援记录 — 地理围栏越界或心跳超时触发，延迟后自动通知邻里圈
/// </summary>
public class AutoRescueRecord
{
    public Guid Id { get; set; }

    /// <summary>老人 ID</summary>
    public Guid ElderId { get; set; }

    /// <summary>老人所在家庭 ID</summary>
    public Guid FamilyId { get; set; }

    /// <summary>老人所在邻里圈 ID</summary>
    public Guid CircleId { get; set; }

    /// <summary>触发类型</summary>
    public RescueTriggerType TriggerType { get; set; }

    /// <summary>救援状态</summary>
    public AutoRescueStatus Status { get; set; } = AutoRescueStatus.WaitingChildResponse;

    /// <summary>触发时间</summary>
    public DateTime TriggeredAt { get; set; } = DateTime.UtcNow;

    /// <summary>子女通知时间</summary>
    public DateTime? ChildNotifiedAt { get; set; }

    /// <summary>子女响应时间</summary>
    public DateTime? ChildRespondedAt { get; set; }

    /// <summary>邻里广播时间</summary>
    public DateTime? BroadcastAt { get; set; }

    /// <summary>解决时间</summary>
    public DateTime? ResolvedAt { get; set; }

    // 导航属性
    public User Elder { get; set; } = null!;
}
