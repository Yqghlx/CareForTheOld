using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Medication;

/// <summary>
/// 记录用药日志请求
/// </summary>
public class RecordMedicationLogRequest
{
    /// <summary>用药计划ID</summary>
    [Required]
    public Guid PlanId { get; set; }

    /// <summary>服药状态</summary>
    [Required]
    public MedicationStatus Status { get; set; }

    /// <summary>计划服药时间</summary>
    [Required]
    public DateTime ScheduledAt { get; set; }

    /// <summary>实际服药时间（已服时填写）</summary>
    public DateTime? TakenAt { get; set; }

    /// <summary>备注</summary>
    [MaxLength(200)]
    public string? Note { get; set; }
}