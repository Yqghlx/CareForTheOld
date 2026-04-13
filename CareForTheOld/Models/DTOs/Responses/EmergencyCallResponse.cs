using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 紧急呼叫响应
/// </summary>
public class EmergencyCallResponse
{
    public Guid Id { get; set; }
    public Guid ElderId { get; set; }
    public string ElderName { get; set; } = string.Empty;
    public Guid FamilyId { get; set; }
    public DateTime CalledAt { get; set; }
    public EmergencyStatus Status { get; set; }
    public Guid? RespondedBy { get; set; }
    public string? RespondedByRealName { get; set; }
    public DateTime? RespondedAt { get; set; }

    /// <summary>
    /// 状态标签
    /// </summary>
    public string StatusLabel => Status == EmergencyStatus.Pending ? "待处理" : "已响应";
}