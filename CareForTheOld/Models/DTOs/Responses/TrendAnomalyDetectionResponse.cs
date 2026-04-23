using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 健康趋势异常检测响应
///
/// 提供个人基线对比、异常事件检测和统计摘要，
/// 用于子女端查看老人健康异常趋势分析。
/// </summary>
public class TrendAnomalyDetectionResponse
{
    /// <summary>健康数据类型</summary>
    public HealthType Type { get; set; }

    /// <summary>健康数据类型名称</summary>
    public string TypeName { get; set; } = string.Empty;

    /// <summary>个人基线（最近30天平均值）</summary>
    public PersonalBaseline Baseline { get; set; } = new();

    /// <summary>检测到的异常事件列表</summary>
    public List<AnomalyEvent> Anomalies { get; set; } = [];

    /// <summary>最近7天统计摘要</summary>
    public RecentStatsSummary RecentStats { get; set; } = new();

    /// <summary>正向激励反馈（数据平稳时生成积极鼓励信息）</summary>
    public PositiveFeedback? PositiveFeedback { get; set; }
}

/// <summary>
/// 个人基线数据（用于对比分析）
/// </summary>
public class PersonalBaseline
{
    /// <summary>基线收缩压（mmHg）- 仅血压类型</summary>
    public double? AvgSystolic { get; set; }

    /// <summary>基线舒张压（mmHg）- 仅血压类型</summary>
    public double? AvgDiastolic { get; set; }

    /// <summary>基线血糖（mmol/L）- 仅血糖类型</summary>
    public double? AvgBloodSugar { get; set; }

    /// <summary>基线心率（bpm）- 仅心率类型</summary>
    public double? AvgHeartRate { get; set; }

    /// <summary>基线体温（°C）- 仅体温类型</summary>
    public double? AvgTemperature { get; set; }

    /// <summary>基线计算周期天数</summary>
    public int BaselineDays { get; set; } = 30;

    /// <summary>基线记录数</summary>
    public int BaselineRecordCount { get; set; }
}

/// <summary>
/// 异常事件
/// </summary>
public class AnomalyEvent
{
    /// <summary>检测时间</summary>
    public DateTime DetectedAt { get; set; }

    /// <summary>异常类型</summary>
    public AnomalyType Type { get; set; }

    /// <summary>异常描述（如"单日收缩压突增至160mmHg，超过基线40%"）</summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>严重度评分（0-100，越高越严重）</summary>
    public double SeverityScore { get; set; }

    /// <summary>异常数值（如160）</summary>
    public double? AnomalyValue { get; set; }

    /// <summary>异常时的基线值（用于对比）</summary>
    public double? BaselineValue { get; set; }

    /// <summary>偏离百分比（如 +40%）</summary>
    public double? DeviationPercent { get; set; }

    /// <summary>行动建议（如"建议今晚清淡饮食，若明早仍高请及时就医"）</summary>
    public string? RecommendedAction { get; set; }
}

/// <summary>
/// 异常类型枚举
/// </summary>
public enum AnomalyType
{
    /// <summary>峰值异常（单值突增/突降）</summary>
    Spike = 1,

    /// <summary>持续异常（连续多天高于/低于基线）</summary>
    ContinuousHigh = 2,

    /// <summary>持续低于基线</summary>
    ContinuousLow = 3,

    /// <summary>加速度异常（连续上升趋势）</summary>
    Acceleration = 4,

    /// <summary>波动性异常（标准差增大）</summary>
    Volatility = 5,
}

/// <summary>
/// 最近统计摘要
/// </summary>
public class RecentStatsSummary
{
    /// <summary>最近7天平均值</summary>
    public double? Avg7Days { get; set; }

    /// <summary>最近7天标准差（波动性指标）</summary>
    public double? StdDev7Days { get; set; }

    /// <summary>最近7天最高值</summary>
    public double? Max7Days { get; set; }

    /// <summary>最近7天最低值</summary>
    public double? Min7Days { get; set; }

    /// <summary>最近7天记录数</summary>
    public int RecordCount7Days { get; set; }

    /// <summary>趋势方向：rising/falling/stable</summary>
    public string? Trend { get; set; }

    /// <summary>与基线对比的偏离百分比</summary>
    public double? BaselineDeviationPercent { get; set; }
}

/// <summary>
/// 正向激励反馈（数据平稳时给予积极鼓励）
///
/// 产品设计意图：算法不应只找"坏数据"，当数据平稳时
/// 应主动生成积极反馈，提升老人成就感和子女安心感。
/// </summary>
public class PositiveFeedback
{
    /// <summary>控制质量评价：极佳/良好/平稳</summary>
    public string Quality { get; set; } = string.Empty;

    /// <summary>鼓励信息（如"过去一周血压控制极佳"）</summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>连续平稳天数</summary>
    public int DaysStable { get; set; }

    /// <summary>变异系数百分比（越小越稳定）</summary>
    public double CoefficientOfVariation { get; set; }
}