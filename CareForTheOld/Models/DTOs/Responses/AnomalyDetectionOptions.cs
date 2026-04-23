namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 异常检测算法可配置选项
///
/// 支持通过 appsettings.json 或数据库 PersonalHealthRule 动态调整阈值。
/// 未来可按用户/健康类型设置不同的个人健康规则。
/// </summary>
public class AnomalyDetectionOptions
{
    /// <summary>峰值异常阈值：单值超过基线的百分比（默认 30%）</summary>
    public double SpikeThresholdPercent { get; set; } = 30;

    /// <summary>持续异常阈值：连续高于/低于基线的百分比（默认 20%）</summary>
    public double ContinuousThresholdPercent { get; set; } = 20;

    /// <summary>持续异常天数阈值：连续多少天异常才触发（默认 3 天）</summary>
    public int ContinuousDaysThreshold { get; set; } = 3;

    /// <summary>波动性异常倍数阈值：近期标准差超过历史的倍数（默认 2 倍）</summary>
    public double VolatilityMultiplierThreshold { get; set; } = 2;

    /// <summary>基线计算天数（默认 30 天）</summary>
    public int BaselineDays { get; set; } = 30;

    /// <summary>最近统计天数（默认 7 天）</summary>
    public int RecentStatsDays { get; set; } = 7;

    /// <summary>最大返回异常事件数（默认 5）</summary>
    public int MaxAnomalies { get; set; } = 5;

    /// <summary>最低检测数据量（默认 5 条）</summary>
    public int MinimumRecordCount { get; set; } = 5;
}
