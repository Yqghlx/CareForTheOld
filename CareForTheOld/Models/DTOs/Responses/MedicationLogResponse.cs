using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 用药日志响应
/// </summary>
public class MedicationLogResponse
{
    public Guid Id { get; set; }
    public Guid PlanId { get; set; }
    public string MedicineName { get; set; } = string.Empty;
    public Guid ElderId { get; set; }
    public string? ElderName { get; set; }
    public MedicationStatus Status { get; set; }
    public DateTime ScheduledAt { get; set; }
    public DateTime? TakenAt { get; set; }
    public string? Note { get; set; }
}