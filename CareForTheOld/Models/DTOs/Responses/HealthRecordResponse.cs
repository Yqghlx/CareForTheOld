using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 健康记录响应
/// </summary>
public class HealthRecordResponse
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string? RealName { get; set; }
    public HealthType Type { get; set; }

    /// <summary>收缩压（mmHg）</summary>
    public int? Systolic { get; set; }

    /// <summary>舒张压（mmHg）</summary>
    public int? Diastolic { get; set; }

    /// <summary>血糖值（mmol/L）</summary>
    public decimal? BloodSugar { get; set; }

    /// <summary>心率（次/分）</summary>
    public int? HeartRate { get; set; }

    /// <summary>体温（°C）</summary>
    public decimal? Temperature { get; set; }

    public string? Note { get; set; }
    public DateTime RecordedAt { get; set; }
    public DateTime CreatedAt { get; set; }
}