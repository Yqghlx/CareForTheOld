using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 健康数据异常检测服务
///
/// 提供基于个人基线的异常检测算法，包括：
/// - 峰值检测（单值突增/突降）
/// - 持续异常（连续多天高于/低于基线）
/// - 加速度检测（连续上升趋势）
/// - 波动性检测（标准差增大）
/// </summary>
public class HealthAnomalyDetector
{
    private readonly ILogger<HealthAnomalyDetector> _logger;

    // 异常检测阈值配置
    private const double SpikeThresholdPercent = 30;  // 峰值异常阈值：超过基线30%
    private const double ContinuousThresholdPercent = 20;  // 持续异常阈值：超过基线20%
    private const int ContinuousDaysThreshold = 3;  // 持续异常天数阈值
    private const double VolatilityMultiplierThreshold = 2;  // 波动性异常阈值：标准差超过历史2倍

    public HealthAnomalyDetector(ILogger<HealthAnomalyDetector> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// 检测健康数据异常
    /// </summary>
    /// <param name="healthRecords">健康记录列表（按时间排序）</param>
    /// <param name="healthType">健康数据类型</param>
    /// <returns>异常检测响应</returns>
    public TrendAnomalyDetectionResponse DetectAnomalies(
        List<(DateTime RecordedAt, double Value)> healthRecords,
        HealthType healthType)
    {
        var response = new TrendAnomalyDetectionResponse
        {
            Type = healthType,
            TypeName = healthType.ToString(),
        };

        if (healthRecords.Count < 5)
        {
            _logger.LogWarning("健康记录数不足（{Count}），无法进行异常检测", healthRecords.Count);
            return response;
        }

        // 按日期分组（每天取一次记录，避免同一天多次记录影响分析）
        var dailyRecords = healthRecords
            .GroupBy(r => r.RecordedAt.Date)
            .Select(g => (Date: g.Key, Value: g.Average(r => r.Value)))
            .OrderBy(r => r.Date)
            .ToList();

        // 计算基线（最近30天平均值）
        var baselinePeriod = dailyRecords
            .Where(r => r.Date >= DateTime.UtcNow.AddDays(-30))
            .ToList();

        var baselineValue = baselinePeriod.Count > 0
            ? baselinePeriod.Average(r => r.Value)
            : dailyRecords.TakeLast(30).Average(r => r.Value);

        response.Baseline = CalculateBaseline(healthType, baselineValue, baselinePeriod.Count);

        // 计算最近7天统计
        var recent7Days = dailyRecords
            .Where(r => r.Date >= DateTime.UtcNow.AddDays(-7))
            .ToList();

        response.RecentStats = CalculateRecentStats(recent7Days, baselineValue);

        // 执行异常检测
        response.Anomalies = DetectAnomalyEvents(dailyRecords, healthType, baselineValue);

        return response;
    }

    /// <summary>
    /// 计算个人基线
    /// </summary>
    private PersonalBaseline CalculateBaseline(HealthType type, double baselineValue, int recordCount)
    {
        var baseline = new PersonalBaseline
        {
            BaselineDays = 30,
            BaselineRecordCount = recordCount,
        };

        switch (type)
        {
            case HealthType.BloodPressure:
                // 血压需要收缩压和舒张压分开处理，这里简化为单一值处理
                // 实际使用时应在 Controller 层分开调用
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
    /// 计算最近7天统计摘要
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

            if (Math.Abs(deviation) > SpikeThresholdPercent)
            {
                anomalies.Add(new AnomalyEvent
                {
                    DetectedAt = record.Date,
                    Type = deviation > 0 ? AnomalyType.Spike : AnomalyType.Spike,
                    Description = deviation > 0
                        ? $"{healthType}值突增至{record.Value:F1}，超过基线{Math.Abs(deviation):F0}%"
                        : $"{healthType}值突降至{record.Value:F1}，低于基线{Math.Abs(deviation):F0}%",
                    SeverityScore = CalculateSeverityScore(Math.Abs(deviation), healthType),
                    AnomalyValue = record.Value,
                    BaselineValue = baselineValue,
                    DeviationPercent = deviation,
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

            if (deviation > ContinuousThresholdPercent)
            {
                continuousHighDays++;
                continuousHighStart = record.Date;
                continuousLowDays = 0;
            }
            else if (deviation < -ContinuousThresholdPercent)
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

            // 达到持续异常阈值
            if (continuousHighDays >= ContinuousDaysThreshold)
            {
                anomalies.Add(new AnomalyEvent
                {
                    DetectedAt = continuousHighStart,
                    Type = AnomalyType.ContinuousHigh,
                    Description = $"{healthType}连续{continuousHighDays}天高于基线20%以上",
                    SeverityScore = CalculateSeverityScore(continuousHighDays * 10, healthType),
                });
                break; // 只报告一次持续异常
            }

            if (continuousLowDays >= ContinuousDaysThreshold)
            {
                anomalies.Add(new AnomalyEvent
                {
                    DetectedAt = continuousLowStart,
                    Type = AnomalyType.ContinuousLow,
                    Description = $"{healthType}连续{continuousLowDays}天低于基线20%以上",
                    SeverityScore = CalculateSeverityScore(continuousLowDays * 10, healthType),
                });
                break;
            }
        }

        // 3. 波动性检测（标准差增大）
        var recent30Days = dailyRecords
            .Where(r => r.Date >= DateTime.UtcNow.AddDays(-30))
            .Select(r => r.Value)
            .ToList();

        var older30Days = dailyRecords
            .Where(r => r.Date < DateTime.UtcNow.AddDays(-30) && r.Date >= DateTime.UtcNow.AddDays(-60))
            .Select(r => r.Value)
            .ToList();

        if (recent30Days.Count >= 7 && older30Days.Count >= 7)
        {
            var recentStdDev = CalculateStdDev(recent30Days);
            var olderStdDev = CalculateStdDev(older30Days);

            if (olderStdDev > 0 && recentStdDev > olderStdDev * VolatilityMultiplierThreshold)
            {
                anomalies.Add(new AnomalyEvent
                {
                    DetectedAt = DateTime.UtcNow,
                    Type = AnomalyType.Volatility,
                    Description = $"最近30天{healthType}波动性增大，标准差较历史升高{(recentStdDev / olderStdDev):F1}倍",
                    SeverityScore = CalculateSeverityScore(recentStdDev / olderStdDev * 20, healthType),
                });
            }
        }

        // 按严重度排序，取前5个最严重的异常
        return anomalies
            .OrderByDescending(a => a.SeverityScore)
            .Take(5)
            .ToList();
    }

    /// <summary>
    /// 计算标准差
    /// </summary>
    private double CalculateStdDev(List<double> values)
    {
        if (values.Count < 2) return 0;

        var avg = values.Average();
        var sumSquares = values.Sum(v => Math.Pow(v - avg, 2));
        return Math.Sqrt(sumSquares / (values.Count - 1));
    }

    /// <summary>
    /// 计算严重度评分（0-100）
    /// </summary>
    private double CalculateSeverityScore(double rawScore, HealthType healthType)
    {
        // 根据健康类型调整严重度权重
        var weight = healthType == HealthType.BloodPressure || healthType == HealthType.BloodSugar
            ? 1.5  // 血压和血糖异常更严重
            : 1.0;

        var score = rawScore * weight;
        return Math.Min(Math.Max(score, 0), 100);  // 限制在0-100范围
    }
}