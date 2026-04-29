using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>用药计划响应</summary>
public class MedicationPlanResponse
{
    /// <summary>计划ID</summary>
    public Guid Id { get; set; }
    /// <summary>老人ID</summary>
    public Guid ElderId { get; set; }
    /// <summary>老人姓名</summary>
    public string? ElderName { get; set; }
    /// <summary>药品名称</summary>
    public string MedicineName { get; set; } = string.Empty;
    /// <summary>剂量</summary>
    public string Dosage { get; set; } = string.Empty;
    /// <summary>服药频率值</summary>
    public Frequency Frequency { get; set; }
    /// <summary>提醒时间列表</summary>
    public List<string> ReminderTimes { get; set; } = new();
    /// <summary>开始日期</summary>
    public DateOnly StartDate { get; set; }
    /// <summary>结束日期，可空</summary>
    public DateOnly? EndDate { get; set; }
    /// <summary>是否激活</summary>
    public bool IsActive { get; set; }
    /// <summary>创建时间</summary>
    public DateTime CreatedAt { get; set; }
    /// <summary>更新时间</summary>
    public DateTime UpdatedAt { get; set; }
}