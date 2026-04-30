namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 自动救援历史记录响应
/// </summary>
public class AutoRescueHistoryResponse
{
    public Guid Id { get; set; }
    public Guid ElderId { get; set; }
    public string ElderName { get; set; } = string.Empty;
    public string TriggerType { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime? TriggeredAt { get; set; }
    public DateTime? ChildNotifiedAt { get; set; }
    public DateTime? ChildRespondedAt { get; set; }
    public DateTime? BroadcastAt { get; set; }
    public DateTime? ResolvedAt { get; set; }
}
