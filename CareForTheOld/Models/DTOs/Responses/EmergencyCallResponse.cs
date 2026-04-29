using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>紧急呼叫响应</summary>
public class EmergencyCallResponse
{
    /// <summary>呼叫ID</summary>
    public Guid Id { get; set; }
    /// <summary>老人ID</summary>
    public Guid ElderId { get; set; }
    /// <summary>老人姓名</summary>
    public string ElderName { get; set; } = string.Empty;
    /// <summary>老人手机号</summary>
    public string? ElderPhoneNumber { get; set; }
    /// <summary>家庭组ID</summary>
    public Guid FamilyId { get; set; }
    /// <summary>呼叫时间</summary>
    public DateTime CalledAt { get; set; }
    /// <summary>呼叫状态</summary>
    public EmergencyStatus Status { get; set; }
    /// <summary>响应者ID，可空</summary>
    public Guid? RespondedBy { get; set; }
    /// <summary>响应者姓名，可空</summary>
    public string? RespondedByRealName { get; set; }
    /// <summary>响应时间，可空</summary>
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