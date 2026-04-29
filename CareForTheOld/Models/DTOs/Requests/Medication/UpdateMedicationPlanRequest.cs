using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Medication;

/// <summary>
/// 更新用药计划请求
/// </summary>
public class UpdateMedicationPlanRequest
{
    /// <summary>药品名称</summary>
    [MaxLength(100)]
    public string? MedicineName { get; set; }

    /// <summary>剂量说明</summary>
    [MaxLength(50)]
    public string? Dosage { get; set; }

    /// <summary>用药频率</summary>
    public Frequency? Frequency { get; set; }

    /// <summary>提醒时间点列表（最多10个时间点，Service 层验证格式）</summary>
    [MaxLength(10)]
    public List<string>? ReminderTimes { get; set; }

    /// <summary>结束日期</summary>
    public DateOnly? EndDate { get; set; }

    /// <summary>是否激活</summary>
    public bool? IsActive { get; set; }
}