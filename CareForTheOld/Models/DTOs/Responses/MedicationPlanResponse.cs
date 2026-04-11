using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 用药计划响应
/// </summary>
public class MedicationPlanResponse
{
    public Guid Id { get; set; }
    public Guid ElderId { get; set; }
    public string? ElderName { get; set; }
    public string MedicineName { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;
    public Frequency Frequency { get; set; }
    public List<string> ReminderTimes { get; set; } = new();
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}