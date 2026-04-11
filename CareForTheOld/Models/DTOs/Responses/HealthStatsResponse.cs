namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 健康数据统计响应
/// </summary>
public class HealthStatsResponse
{
    /// <summary>健康数据类型名称</summary>
    public string TypeName { get; set; } = string.Empty;

    /// <summary>最近7天平均值</summary>
    public decimal? Average7Days { get; set; }

    /// <summary>最近30天平均值</summary>
    public decimal? Average30Days { get; set; }

    /// <summary>最近记录值</summary>
    public decimal? LatestValue { get; set; }

    /// <summary>最近记录时间</summary>
    public DateTime? LatestRecordedAt { get; set; }

    /// <summary>记录总数</summary>
    public int TotalCount { get; set; }
}