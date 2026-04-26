using CareForTheOld.Common.Constants;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 健康数据异常检测服务
///
/// 提供基于个人基线的异常检测算法，包括：
/// - 峰值检测（单值突增/突降）
/// - 持续异常（连续多天高于/低于基线）
/// - 加速度检测（连续上升趋势）
/// - 波动性检测（标准差增大）
/// - 正向激励（数据平稳时的积极反馈）
///
/// 支持时区感知的日期分组和可配置的检测阈值。
/// </summary>
public class HealthAnomalyDetector
{
    private readonly ILogger<HealthAnomalyDetector> _logger;
    private readonly AnomalyDetectionOptions _options;

    public HealthAnomalyDetector(
        ILogger<HealthAnomalyDetector> logger,
        IOptions<AnomalyDetectionOptions>? options = null)
    {
        _logger = logger;
        _options = options?.Value ?? new AnomalyDetectionOptions();
    }

    /// <summary>
    /// 检测健康数据异常
    /// </summary>
    /// <param name="healthRecords">健康记录列表（按时间排序）</param>
    /// <param name="healthType">健康数据类型</param>
    /// <param name="timezoneOffsetHours">用户时区偏移（小时），默认 0（UTC），中国为 8</param>
    /// <returns>异常检测响应</returns>
    public TrendAnomalyDetectionResponse DetectAnomalies(
        List<(DateTime RecordedAt, double Value)> healthRecords,
        HealthType healthType,
        double timezoneOffsetHours = 0)
    {
        var response = new TrendAnomalyDetectionResponse
        {
            Type = healthType,
            TypeName = healthType.ToString(),
        };

        if (healthRecords.Count < _options.MinimumRecordCount)
        {
            _logger.LogWarning("健康记录数不足（{Count}），无法进行异常检测", healthRecords.Count);
            return response;
        }

        // 按用户本地日期分组（每天取均值，避免同一天多次记录影响分析）
        var dailyRecords = healthRecords
            .GroupBy(r => r.RecordedAt.AddHours(timezoneOffsetHours).Date)
            .Select(g => (Date: g.Key, Value: g.Average(r => r.Value)))
            .OrderBy(r => r.Date)
            .ToList();

        // 计算基线（最近 N 天平均值）
        var baselinePeriod = dailyRecords
            .Where(r => r.Date >= DateTime.UtcNow.AddHours(timezoneOffsetHours).AddDays(-_options.BaselineDays))
            .ToList();

        var baselineValue = baselinePeriod.Count > 0
            ? baselinePeriod.Average(r => r.Value)
            : dailyRecords.TakeLast(_options.BaselineDays).Average(r => r.Value);

        response.Baseline = CalculateBaseline(healthType, baselineValue, baselinePeriod.Count);

        // 计算最近 N 天统计
        var recentDays = dailyRecords
            .Where(r => r.Date >= DateTime.UtcNow.AddHours(timezoneOffsetHours).AddDays(-_options.RecentStatsDays))
            .ToList();

        response.RecentStats = CalculateRecentStats(recentDays, baselineValue);

        // 执行异常检测
        response.Anomalies = DetectAnomalyEvents(dailyRecords, healthType, baselineValue);

        // 正向激励：数据平稳时给予积极反馈
        if (response.Anomalies.Count == 0 && dailyRecords.Count >= _options.BaselineDays)
        {
            response.PositiveFeedback = GeneratePositiveFeedback(healthType, baselineValue, recentDays);
        }

        return response;
    }

    /// <summary>
    /// 生成正向激励反馈（数据平稳时的积极鼓励）
    ///
    /// 产品设计意图：人在看到异常时会产生恐慌，而当一切正常时缺乏感知。
    /// 正向激励填补了这一体验缝隙，提升老人成就感和子女安心感。
    /// </summary>
    private PositiveFeedback? GeneratePositiveFeedback(
        HealthType healthType,
        double baselineValue,
        List<(DateTime Date, double Value)> recentDays)
    {
        if (recentDays.Count < Math.Max(5, _options.RecentStatsDays - 2)) return null;

        var stdDev = CalculateStdDev(recentDays.Select(r => r.Value).ToList());
        var coefficientOfVariation = baselineValue > 0 ? stdDev / baselineValue : 0;

        // 变异系数 < 10% 视为极佳控制
        var quality = coefficientOfVariation switch
        {
            < AppConstants.AnomalyEvaluation.CoefficientOfVariationExcellent => AppConstants.AnomalyEvaluation.QualityExcellent,
            < AppConstants.AnomalyEvaluation.CoefficientOfVariationGood => AppConstants.AnomalyEvaluation.QualityGood,
            _ => AppConstants.AnomalyEvaluation.QualityStable,
        };

        var healthLabel = healthType switch
        {
            HealthType.BloodPressure => AppConstants.HealthTypeLabels.BloodPressure,
            HealthType.BloodSugar => AppConstants.HealthTypeLabels.BloodSugar,
            HealthType.HeartRate => AppConstants.HealthTypeLabels.HeartRate,
            HealthType.Temperature => AppConstants.HealthTypeLabels.Temperature,
            _ => AppConstants.AnomalyEvaluation.DefaultHealthLabel,
        };

        var message = quality == AppConstants.AnomalyEvaluation.QualityExcellent
            ? $"过去一周{healthLabel}控制极佳，波动极小，请继续保持良好的生活习惯！"
            : quality == AppConstants.AnomalyEvaluation.QualityGood
                ? $"过去一周{healthLabel}控制良好，数据波动在正常范围内。"
                : $"过去一周{healthLabel}数据保持平稳，一切正常。";

        return new PositiveFeedback
        {
            Quality = quality,
            Message = message,
            DaysStable = recentDays.Count,
            CoefficientOfVariation = Math.Round(coefficientOfVariation * 100, 1),
        };
    }

    /// <summary>
    /// 计算个人基线
    /// </summary>
    private PersonalBaseline CalculateBaseline(HealthType type, double baselineValue, int recordCount)
    {
        var baseline = new PersonalBaseline
        {
            BaselineDays = _options.BaselineDays,
            BaselineRecordCount = recordCount,
        };

        switch (type)
        {
            case HealthType.BloodPressure:
                baseline.AvgSystolic = baselineValue;
                break;
            case HealthType.BloodSugar:
                baseline.AvgBloodSugar = baselineValue;
                break;
            case HealthType.HeartRate:
                baseline.AvgHeartRate = baselineValue;
                break;
            case HealthType.Temperature:
                baseline.AvgTemperature = baselineValue;
                break;
        }

        return baseline;
    }

    /// <summary>
    /// 计算最近统计摘要
    /// </summary>
    private RecentStatsSummary CalculateRecentStats(
        List<(DateTime Date, double Value)> recentRecords,
        double baselineValue)
    {
        if (recentRecords.Count == 0)
        {
            return new RecentStatsSummary();
        }

        var avg = recentRecords.Average(r => r.Value);
        var stdDev = CalculateStdDev(recentRecords.Select(r => r.Value).ToList());
        var max = recentRecords.Max(r => r.Value);
        var min = recentRecords.Min(r => r.Value);

        // 计算趋势
        var firstHalf = recentRecords.Take(recentRecords.Count / 2).ToList();
        var secondHalf = recentRecords.Skip(recentRecords.Count / 2).ToList();

        string? trend = null;
        if (firstHalf.Count > 0 && secondHalf.Count > 0)
        {
            var firstAvg = firstHalf.Average(r => r.Value);
            var secondAvg = secondHalf.Average(r => r.Value);
            var trendDiff = (secondAvg - firstAvg) / firstAvg * 100;

            if (trendDiff > 5) trend = "rising";
            else if (trendDiff < -5) trend = "falling";
            else trend = "stable";
        }

        // 计算与基线的偏离
        double? baselineDeviation = baselineValue > 0
            ? (avg - baselineValue) / baselineValue * 100
            : null;

        return new RecentStatsSummary
        {
            Avg7Days = avg,
            StdDev7Days = stdDev,
            Max7Days = max,
            Min7Days = min,
            RecordCount7Days = recentRecords.Count,
            Trend = trend,
            BaselineDeviationPercent = baselineDeviation,
        };
    }

    /// <summary>
    /// 检测异常事件
    /// </summary>
    private List<AnomalyEvent> DetectAnomalyEvents(
        List<(DateTime Date, double Value)> dailyRecords,
        HealthType healthType,
        double baselineValue)
    {
        var anomalies = new List<AnomalyEvent>();

        // 1. 峰值检测（单值突增/突降）
        foreach (var record in dailyRecords)
        {
            var deviation = (record.Value - baselineValue) / baselineValue * 100;

            if (Math.Abs(deviation) > _options.SpikeThresholdPercent)
            {
                anomalies.Add(new AnomalyEvent
                {
                    DetectedAt = record.Date,
                    Type = AnomalyType.Spike,
                    Description = deviation > 0
                        ? $"{healthType}值突增至{record.Value:F1}，超过基线{Math.Abs(deviation):F0}%"
                        : $"{healthType}值突降至{record.Value:F1}，低于基线{Math.Abs(deviation):F0}%",
                    SeverityScore = CalculateSeverityScore(Math.Abs(deviation), healthType),
                    AnomalyValue = record.Value,
                    BaselineValue = baselineValue,
                    DeviationPercent = deviation,
                    RecommendedAction = GetRecommendedAction(AnomalyType.Spike, healthType, deviation),
                });
            }
        }

        // 2. 持续异常检测（连续多天高于/低于基线）
        var continuousHighDays = 0;
        var continuousLowDays = 0;
        var continuousHighStart = DateTime.MinValue;
        var continuousLowStart = DateTime.MinValue;

        foreach (var record in dailyRecords.OrderByDescending(r => r.Date))
        {
            var deviation = (record.Value - baselineValue) / baselineValue * 100;

            if (deviation > _options.ContinuousThresholdPercent)
            {
                continuousHighDays++;
                continuousHighStart = record.Date;
                continuousLowDays = 0;
            }
            else if (deviation < -_options.ContinuousThresholdPercent)
            {
                continuousLowDays++;
                continuousLowStart = record.Date;
                continuousHighDays = 0;
            }
            else
            {
                continuousHighDays = 0;
                continuousLowDays = 0;
            }

            if (continuousHighDays >= _options.ContinuousDaysThreshold)
            {
                anomalies.Add(new AnomalyEvent
                {
                    DetectedAt = continuousHighStart,
                    Type = AnomalyType.ContinuousHigh,
                    Description = $"{healthType}连续{continuousHighDays}天高于基线{_options.ContinuousThresholdPercent}%以上",
                    SeverityScore = CalculateSeverityScore(continuousHighDays * 10, healthType),
                    RecommendedAction = GetRecommendedAction(AnomalyType.ContinuousHigh, healthType, 0),
                });
                break;
            }

            if (continuousLowDays >= _options.ContinuousDaysThreshold)
            {
                anomalies.Add(new AnomalyEvent
                {
                    DetectedAt = continuousLowStart,
                    Type = AnomalyType.ContinuousLow,
                    Description = $"{healthType}连续{continuousLowDays}天低于基线{_options.ContinuousThresholdPercent}%以上",
                    SeverityScore = CalculateSeverityScore(continuousLowDays * 10, healthType),
                    RecommendedAction = GetRecommendedAction(AnomalyType.ContinuousLow, healthType, 0),
                });
                break;
            }
        }

        // 3. 波动性检测（标准差增大）
        var nowLocal = DateTime.UtcNow; // 近期窗口参考时间
        var recentWindow = dailyRecords
            .Where(r => r.Date >= nowLocal.AddDays(-_options.BaselineDays))
            .Select(r => r.Value)
            .ToList();

        var olderWindow = dailyRecords
            .Where(r => r.Date < nowLocal.AddDays(-_options.BaselineDays) && r.Date >= nowLocal.AddDays(-_options.BaselineDays * 2))
            .Select(r => r.Value)
            .ToList();

        if (recentWindow.Count >= 7 && olderWindow.Count >= 7)
        {
            var recentStdDev = CalculateStdDev(recentWindow);
            var olderStdDev = CalculateStdDev(olderWindow);

            if (olderStdDev > 0 && recentStdDev > olderStdDev * _options.VolatilityMultiplierThreshold)
            {
                anomalies.Add(new AnomalyEvent
                {
                    DetectedAt = DateTime.UtcNow,
                    Type = AnomalyType.Volatility,
                    Description = $"最近{_options.BaselineDays}天{healthType}波动性增大，标准差较历史升高{(recentStdDev / olderStdDev):F1}倍",
                    SeverityScore = CalculateSeverityScore(recentStdDev / olderStdDev * 20, healthType),
                    RecommendedAction = GetRecommendedAction(AnomalyType.Volatility, healthType, 0),
                });
            }
        }

        // 按严重度排序，取前 N 个最严重的异常
        return anomalies
            .OrderByDescending(a => a.SeverityScore)
            .Take(_options.MaxAnomalies)
            .ToList();
    }

    /// <summary>
    /// 根据异常类型和健康类型生成行动建议
    ///
    /// 产品设计意图：从"描述事实"升级为"提供行动指南（Call to Action）"，
    /// 在用户看到异常时给予温和、专业的就医/生活方式建议，避免假性医疗恐慌。
    /// </summary>
    private string GetRecommendedAction(AnomalyType anomalyType, HealthType healthType, double deviation)
    {
        return anomalyType switch
        {
            AnomalyType.Spike => healthType switch
            {
                HealthType.BloodPressure => deviation > 0
                    ? HealthAlertMessages.AnomalySuggestions.Spike.BloodPressureHigh
                    : HealthAlertMessages.AnomalySuggestions.Spike.BloodPressureLow,
                HealthType.BloodSugar => deviation > 0
                    ? HealthAlertMessages.AnomalySuggestions.Spike.BloodSugarHigh
                    : HealthAlertMessages.AnomalySuggestions.Spike.BloodSugarLow,
                HealthType.HeartRate => deviation > 0
                    ? HealthAlertMessages.AnomalySuggestions.Spike.HeartRateHigh
                    : HealthAlertMessages.AnomalySuggestions.Spike.HeartRateLow,
                HealthType.Temperature => deviation > 0
                    ? HealthAlertMessages.AnomalySuggestions.Spike.TemperatureHigh
                    : HealthAlertMessages.AnomalySuggestions.Spike.TemperatureLow,
                _ => HealthAlertMessages.AnomalySuggestions.General,
            },
            AnomalyType.ContinuousHigh => healthType switch
            {
                HealthType.BloodPressure => HealthAlertMessages.AnomalySuggestions.ContinuousHigh.BloodPressure,
                HealthType.BloodSugar => HealthAlertMessages.AnomalySuggestions.ContinuousHigh.BloodSugar,
                HealthType.HeartRate => HealthAlertMessages.AnomalySuggestions.ContinuousHigh.HeartRate,
                HealthType.Temperature => HealthAlertMessages.AnomalySuggestions.ContinuousHigh.Temperature,
                _ => HealthAlertMessages.AnomalySuggestions.GeneralHigh,
            },
            AnomalyType.ContinuousLow => healthType switch
            {
                HealthType.BloodPressure => HealthAlertMessages.AnomalySuggestions.ContinuousLow.BloodPressure,
                HealthType.BloodSugar => HealthAlertMessages.AnomalySuggestions.ContinuousLow.BloodSugar,
                HealthType.HeartRate => HealthAlertMessages.AnomalySuggestions.ContinuousLow.HeartRate,
                HealthType.Temperature => HealthAlertMessages.AnomalySuggestions.ContinuousLow.Temperature,
                _ => HealthAlertMessages.AnomalySuggestions.GeneralLow,
            },
            AnomalyType.Volatility => healthType switch
            {
                HealthType.BloodPressure => HealthAlertMessages.AnomalySuggestions.Volatility.BloodPressure,
                HealthType.BloodSugar => HealthAlertMessages.AnomalySuggestions.Volatility.BloodSugar,
                HealthType.HeartRate => HealthAlertMessages.AnomalySuggestions.Volatility.HeartRate,
                _ => HealthAlertMessages.AnomalySuggestions.GeneralVolatility,
            },
            _ => HealthAlertMessages.AnomalySuggestions.General,
        };
    }

    /// <summary>
    /// 计算标准差
    /// </summary>
    private static double CalculateStdDev(List<double> values)
    {
        if (values.Count < 2) return 0;

        var avg = values.Average();
        var sumSquares = values.Sum(v => Math.Pow(v - avg, 2));
        return Math.Sqrt(sumSquares / (values.Count - 1));
    }

    /// <summary>
    /// 计算严重度评分（0-100）
    /// </summary>
    private static double CalculateSeverityScore(double rawScore, HealthType healthType)
    {
        // 根据健康类型调整严重度权重：血压和血糖异常更严重
        const double criticalTypeWeight = 1.5;
        const double normalTypeWeight = 1.0;
        var weight = healthType == HealthType.BloodPressure || healthType == HealthType.BloodSugar
            ? criticalTypeWeight
            : normalTypeWeight;

        var score = rawScore * weight;
        return Math.Min(Math.Max(score, 0), 100);
    }
}
