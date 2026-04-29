using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>用药记录响应</summary>
public class MedicationLogResponse
{
    /// <summary>记录ID</summary>
    public Guid Id { get; set; }
    /// <summary>用药计划ID</summary>
    public Guid PlanId { get; set; }
    /// <summary>药品名称</summary>
    public string MedicineName { get; set; } = string.Empty;
    /// <summary>老人ID</summary>
    public Guid ElderId { get; set; }
    /// <summary>老人姓名</summary>
    public string? ElderName { get; set; }
    /// <summary>服药状态</summary>
    public MedicationStatus Status { get; set; }
    /// <summary>计划服药时间</summary>
    public DateTime ScheduledAt { get; set; }
    /// <summary>实际服药时间，可空</summary>
    public DateTime? TakenAt { get; set; }
    /// <summary>备注，可空</summary>
    public string? Note { get; set; }
}