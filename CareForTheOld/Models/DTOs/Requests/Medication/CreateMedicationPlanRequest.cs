using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Medication;

/// <summary>
/// 创建用药计划请求
/// </summary>
public class CreateMedicationPlanRequest
{
    /// <summary>老人用户ID</summary>
    [Required]
    public Guid ElderId { get; set; }

    /// <summary>药品名称</summary>
    [Required]
    [MaxLength(100)]
    public string MedicineName { get; set; } = string.Empty;

    /// <summary>剂量说明</summary>
    [Required]
    [MaxLength(50)]
    public string Dosage { get; set; } = string.Empty;

    /// <summary>用药频率</summary>
    [Required]
    public Frequency Frequency { get; set; }

    /// <summary>提醒时间点列表，格式如 ["08:00","14:00"]</summary>
    [Required]
    [MinLength(1, ErrorMessage = "至少需要一个提醒时间")]
    [MaxLength(10)]
    public List<string> ReminderTimes { get; set; } = new();

    /// <summary>开始日期</summary>
    [Required]
    public DateOnly StartDate { get; set; }

    /// <summary>结束日期（可选）</summary>
    public DateOnly? EndDate { get; set; }
}