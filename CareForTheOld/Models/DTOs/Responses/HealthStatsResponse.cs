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

    /// <summary>
    /// 趋势方向："rising"(升高)、"falling"(降低)、"stable"(稳定)、null(数据不足)
    /// 基于 7 天均值与 30 天均值的对比计算
    /// </summary>
    public string? Trend { get; set; }

    /// <summary>
    /// 趋势预警提示（如"近7天血压均值较30天均值升高约12%，请关注"），无异常时为 null
    /// </summary>
    public string? TrendWarning { get; set; }
}