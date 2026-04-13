using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 紧急呼叫实体
/// </summary>
public class EmergencyCall
{
    public Guid Id { get; set; }

    /// <summary>
    /// 发起呼叫的老人ID
    /// </summary>
    public Guid ElderId { get; set; }

    /// <summary>
    /// 所属家庭组ID
    /// </summary>
    public Guid FamilyId { get; set; }

    /// <summary>
    /// 呼叫时间
    /// </summary>
    public DateTime CalledAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 呼叫状态
    /// </summary>
    public EmergencyStatus Status { get; set; } = EmergencyStatus.Pending;

    /// <summary>
    /// 响应者ID（子女）
    /// </summary>
    public Guid? RespondedBy { get; set; }

    /// <summary>
    /// 响应时间
    /// </summary>
    public DateTime? RespondedAt { get; set; }

    /// <summary>
    /// 响应者姓名
    /// </summary>
    public string? RespondedByRealName { get; set; }

    // 导航属性
    public User Elder { get; set; } = null!;
    public Family Family { get; set; } = null!;
}