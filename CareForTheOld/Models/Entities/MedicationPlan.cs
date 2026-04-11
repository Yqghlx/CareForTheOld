using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 用药计划实体
/// </summary>
public class MedicationPlan
{
    public Guid Id { get; set; }
    public Guid ElderId { get; set; }
    public string MedicineName { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;
    public Frequency Frequency { get; set; }

    /// <summary>提醒时间点列表，JSON 格式存储，如 ["08:00","14:00","20:00"]</summary>
    public string ReminderTimes { get; set; } = "[]";
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public User Elder { get; set; } = null!;
    public ICollection<MedicationLog> MedicationLogs { get; set; } = [];
}