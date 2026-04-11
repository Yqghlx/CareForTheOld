using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 服药记录实体
/// </summary>
public class MedicationLog
{
    public Guid Id { get; set; }
    public Guid PlanId { get; set; }
    public Guid ElderId { get; set; }
    public MedicationStatus Status { get; set; }
    public DateTime ScheduledAt { get; set; }
    public DateTime? TakenAt { get; set; }
    public string? Note { get; set; }

    // 导航属性
    public MedicationPlan Plan { get; set; } = null!;
    public User Elder { get; set; } = null!;
}