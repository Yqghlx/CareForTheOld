using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 邻里求助请求实体（关联紧急呼叫，广播给附近邻居）
/// </summary>
public class NeighborHelpRequest
{
    public Guid Id { get; set; }

    /// <summary>关联的紧急呼叫 ID</summary>
    public Guid EmergencyCallId { get; set; }

    /// <summary>所属邻里圈 ID</summary>
    public Guid CircleId { get; set; }

    /// <summary>发起求助的老人 ID</summary>
    public Guid RequesterId { get; set; }

    /// <summary>响应的邻居 ID</summary>
    public Guid? ResponderId { get; set; }

    public HelpRequestStatus Status { get; set; } = HelpRequestStatus.Pending;

    /// <summary>求助时纬度</summary>
    public double? Latitude { get; set; }

    /// <summary>求助时经度</summary>
    public double? Longitude { get; set; }

    public DateTime RequestedAt { get; set; } = DateTime.UtcNow;

    /// <summary>邻居响应时间</summary>
    public DateTime? RespondedAt { get; set; }

    /// <summary>过期时间（默认 15 分钟）</summary>
    public DateTime ExpiresAt { get; set; }

    /// <summary>取消时间</summary>
    public DateTime? CancelledAt { get; set; }

    /// <summary>取消操作者 ID</summary>
    public Guid? CancelledBy { get; set; }

    // 导航属性
    public EmergencyCall EmergencyCall { get; set; } = null!;
    public NeighborCircle Circle { get; set; } = null!;
    public User Requester { get; set; } = null!;
    public User? Responder { get; set; }
}
