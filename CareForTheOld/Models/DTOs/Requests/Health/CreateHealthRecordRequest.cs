using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Health;

/// <summary>
/// 创建健康记录请求
/// </summary>
public class CreateHealthRecordRequest
{
    /// <summary>健康数据类型</summary>
    [Required]
    public HealthType Type { get; set; }

    /// <summary>收缩压（mmHg），血压类型时必填</summary>
    [Range(60, 250)]
    public int? Systolic { get; set; }

    /// <summary>舒张压（mmHg），血压类型时必填</summary>
    [Range(40, 150)]
    public int? Diastolic { get; set; }

    /// <summary>血糖值（mmol/L）</summary>
    [Range(1.0, 35.0)]
    public decimal? BloodSugar { get; set; }

    /// <summary>心率（次/分）</summary>
    [Range(30, 200)]
    public int? HeartRate { get; set; }

    /// <summary>体温（°C）</summary>
    [Range(35.0, 42.0)]
    public decimal? Temperature { get; set; }

    /// <summary>备注</summary>
    [MaxLength(500)]
    public string? Note { get; set; }

    /// <summary>记录时间</summary>
    public DateTime? RecordedAt { get; set; }
}