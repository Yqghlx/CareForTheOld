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
    public string? ElderPhoneNumber { get; set; }
    public Guid FamilyId { get; set; }
    public DateTime CalledAt { get; set; }
    public EmergencyStatus Status { get; set; }
    public Guid? RespondedBy { get; set; }
    public string? RespondedByRealName { get; set; }
    public DateTime? RespondedAt { get; set; }

    /// <summary>
    /// 呼叫时纬度
    /// </summary>
    public double? Latitude { get; set; }

    /// <summary>
    /// 呼叫时经度
    /// </summary>
    public double? Longitude { get; set; }

    /// <summary>
    /// 呼叫时电池电量百分比（0~100）
    /// </summary>
    public int? BatteryLevel { get; set; }

    /// <summary>
    /// 状态标签
    /// </summary>
    public string StatusLabel => Status.GetLabel();
}