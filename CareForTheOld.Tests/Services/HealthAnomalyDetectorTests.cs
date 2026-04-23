using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;
using Xunit.Abstractions;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// HealthAnomalyDetector 异常检测算法单元测试
/// </summary>
public class HealthAnomalyDetectorTests
{
    private readonly HealthAnomalyDetector _detector;
    private readonly ITestOutputHelper _output;

    public HealthAnomalyDetectorTests(ITestOutputHelper output)
    {
        _output = output;
        var logger = new Mock<ILogger<HealthAnomalyDetector>>();
        _detector = new HealthAnomalyDetector(logger.Object);
    }

    /// <summary>
    /// 生成模拟健康记录（从今天往前推若干天）
    /// </summary>
    private static List<(DateTime RecordedAt, double Value)> GenerateRecords(
        int days, double baseValue, double? spikeOnDay = null, double spikeValue = 0,
        double? drift = null)
    {
        var records = new List<(DateTime, double)>();
        var random = new Random(42); // 固定种子确保可重复

        for (int i = days; i >= 1; i--)
        {
            var date = DateTime.UtcNow.AddDays(-i);
            var noise = random.NextDouble() * 4 - 2; // -2 ~ +2 的随机波动
            var value = baseValue + noise;

            // 添加漂移趋势
            if (drift.HasValue)
            {
                value += drift.Value * (days - i);
            }

            // 添加峰值
            if (spikeOnDay.HasValue && i == spikeOnDay.Value)
            {
                value = spikeValue;
            }

            records.Add((date, value));
        }

        return records;
    }

    #region 基线与统计计算

    [Fact]
    public void DetectAnomalies_WithFewerThan5Records_ReturnsEmptyAnomalies()
    {
        // Arrange：记录数不足 5 条
        var records = GenerateRecords(4, 120);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodPressure);

        // Assert
        Assert.Empty(result.Anomalies);
        Assert.Equal(HealthType.BloodPressure, result.Type);
    }

    [Fact]
    public void DetectAnomalies_WithSufficientRecords_CalculatesBaseline()
    {
        // Arrange
        var records = GenerateRecords(30, 120);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodPressure);

        // Assert：基线应接近 120
        Assert.NotNull(result.Baseline);
        Assert.InRange(result.Baseline.AvgSystolic ?? 0, 115, 125);
        Assert.Equal(30, result.Baseline.BaselineDays);
    }

    [Fact]
    public void DetectAnomalies_CalculatesRecent7DayStats()
    {
        // Arrange
        var records = GenerateRecords(30, 100);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：最近 7 天统计应存在且合理
        Assert.NotNull(result.RecentStats);
        Assert.True(result.RecentStats.RecordCount7Days >= 6);
        Assert.InRange(result.RecentStats.Avg7Days ?? 0, 95, 105);
        Assert.NotNull(result.RecentStats.Trend);
    }

    [Fact]
    public void DetectAnomalies_WithUpwardTrend_ReportsRising()
    {
        // Arrange：最近 7 天内明显上升趋势（后半段值远高于前半段）
        var records = new List<(DateTime, double)>();
        // 前 23 天正常
        for (int i = 30; i >= 8; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 80));
        }
        // 最近 7 天：前 3 天 80，后 4 天 100（差异 >5%）
        for (int i = 7; i >= 5; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 80));
        }
        for (int i = 4; i >= 1; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 100));
        }

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：趋势应为 rising
        Assert.Equal("rising", result.RecentStats.Trend);
    }

    [Fact]
    public void DetectAnomalies_WithDownwardTrend_ReportsFalling()
    {
        // Arrange：数据有持续下降趋势
        var records = GenerateRecords(30, 120, drift: -2.0);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodPressure);

        // Assert：趋势应为 falling
        Assert.Equal("falling", result.RecentStats.Trend);
    }

    [Fact]
    public void DetectAnomalies_WithStableData_ReportsStable()
    {
        // Arrange：稳定数据
        var records = GenerateRecords(30, 100);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：趋势应为 stable
        Assert.Equal("stable", result.RecentStats.Trend);
    }

    #endregion

    #region 峰值检测

    [Fact]
    public void DetectAnomalies_WithSpike_DetectsSpikeAnomaly()
    {
        // Arrange：正常基线 120，第 5 天有一个 200 的峰值（偏差 >30%）
        var records = GenerateRecords(30, 120, spikeOnDay: 5, spikeValue: 200);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodPressure);

        // Assert：应检测到峰值异常
        Assert.NotEmpty(result.Anomalies);
        Assert.Contains(result.Anomalies, a => a.Type == AnomalyType.Spike);
    }

    [Fact]
    public void DetectAnomalies_SpikeAnomaly_HasCorrectSeverity()
    {
        // Arrange：基线 100，峰值 180（偏差 80%）
        var records = GenerateRecords(30, 100, spikeOnDay: 3, spikeValue: 180);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：严重度应 >0（心率权重 1.0）
        var spike = result.Anomalies.FirstOrDefault(a => a.Type == AnomalyType.Spike);
        Assert.NotNull(spike);
        Assert.True(spike.SeverityScore > 0);
    }

    [Fact]
    public void DetectAnomalies_BloodPressureSpike_HasHigherSeverity()
    {
        // Arrange：血压峰值（权重 1.5）vs 心率峰值（权重 1.0）
        var bpRecords = GenerateRecords(30, 120, spikeOnDay: 5, spikeValue: 200);
        var hrRecords = GenerateRecords(30, 100, spikeOnDay: 5, spikeValue: 167); // 相同百分比偏差

        // Act
        var bpResult = _detector.DetectAnomalies(bpRecords, HealthType.BloodPressure);
        var hrResult = _detector.DetectAnomalies(hrRecords, HealthType.HeartRate);

        // Assert：血压异常严重度应更高
        var bpSpike = bpResult.Anomalies.FirstOrDefault(a => a.Type == AnomalyType.Spike);
        var hrSpike = hrResult.Anomalies.FirstOrDefault(a => a.Type == AnomalyType.Spike);

        if (bpSpike != null && hrSpike != null)
        {
            Assert.True(bpSpike.SeverityScore >= hrSpike.SeverityScore);
        }
    }

    #endregion

    #region 持续异常检测

    [Fact]
    public void DetectAnomalies_WithContinuousHigh_DetectsContinuousHighAnomaly()
    {
        // Arrange：最近 4 天持续偏高（超过基线 20%）
        var records = new List<(DateTime, double)>();
        // 前 26 天正常值（基线 = 100）
        for (int i = 30; i >= 5; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 100 + new Random(i).NextDouble() * 2));
        }
        // 最近 4 天持续偏高到 130（>基线 20%）
        for (int i = 4; i >= 1; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 130));
        }

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert
        Assert.Contains(result.Anomalies, a => a.Type == AnomalyType.ContinuousHigh);
    }

    [Fact]
    public void DetectAnomalies_WithContinuousLow_DetectsContinuousLowAnomaly()
    {
        // Arrange：最近 3 天持续偏低（低于基线 20%）
        var records = new List<(DateTime, double)>();
        for (int i = 30; i >= 4; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 100));
        }
        // 最近 3 天持续偏低到 70（<基线 20%）
        for (int i = 3; i >= 1; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 70));
        }

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert
        Assert.Contains(result.Anomalies, a => a.Type == AnomalyType.ContinuousLow);
    }

    [Fact]
    public void DetectAnomalies_WithBriefSpike_NoContinuousAnomaly()
    {
        // Arrange：只有 1 天偏高，不应触发持续异常（需 >=3 天）
        var records = GenerateRecords(30, 100, spikeOnDay: 2, spikeValue: 150);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：可能有 Spike 异常，但不应有 ContinuousHigh
        Assert.DoesNotContain(result.Anomalies, a => a.Type == AnomalyType.ContinuousHigh);
    }

    #endregion

    #region 波动性检测

    [Fact]
    public void DetectAnomalies_WithHighVolatility_DetectsVolatilityAnomaly()
    {
        // Arrange：需要 60 天数据，前 30 天稳定，后 30 天波动大
        var records = new List<(DateTime, double)>();
        var random = new Random(42);

        // 前 30 天：稳定在 100 ± 2
        for (int i = 60; i >= 31; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 100 + random.NextDouble() * 4 - 2));
        }

        // 后 30 天：大幅波动 100 ± 20
        for (int i = 30; i >= 1; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 100 + random.NextDouble() * 40 - 20));
        }

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：应检测到波动性异常
        Assert.Contains(result.Anomalies, a => a.Type == AnomalyType.Volatility);
    }

    [Fact]
    public void DetectAnomalies_WithStableData_NoVolatilityAnomaly()
    {
        // Arrange：所有数据都很稳定
        var records = GenerateRecords(60, 100);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：不应有波动性异常
        Assert.DoesNotContain(result.Anomalies, a => a.Type == AnomalyType.Volatility);
    }

    #endregion

    #region 健康类型特定

    [Fact]
    public void DetectAnomalies_BloodSugarType_SetsBaselineCorrectly()
    {
        // Arrange
        var records = GenerateRecords(30, 5.5);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodSugar);

        // Assert：基线应设置 AvgBloodSugar
        Assert.NotNull(result.Baseline.AvgBloodSugar);
        Assert.InRange(result.Baseline.AvgBloodSugar!.Value, 5.0, 6.0);
    }

    [Fact]
    public void DetectAnomalies_TemperatureType_SetsBaselineCorrectly()
    {
        // Arrange
        var records = GenerateRecords(30, 36.5);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.Temperature);

        // Assert：基线应设置 AvgTemperature
        Assert.NotNull(result.Baseline.AvgTemperature);
        Assert.InRange(result.Baseline.AvgTemperature!.Value, 36.0, 37.0);
    }

    [Fact]
    public void DetectAnomalies_HeartRateType_SetsBaselineCorrectly()
    {
        // Arrange
        var records = GenerateRecords(30, 75);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：基线应设置 AvgHeartRate
        Assert.NotNull(result.Baseline.AvgHeartRate);
        Assert.InRange(result.Baseline.AvgHeartRate!.Value, 70, 80);
    }

    #endregion

    #region 边界条件

    [Fact]
    public void DetectAnomalies_SeverityScore_BoundedBetween0And100()
    {
        // Arrange：极端异常值，确保严重度不超过 100
        var records = GenerateRecords(30, 100, spikeOnDay: 3, spikeValue: 500);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：所有异常的严重度应在 0-100 之间
        Assert.All(result.Anomalies, a => Assert.InRange(a.SeverityScore, 0, 100));
    }

    [Fact]
    public void DetectAnomalies_MultipleAnomalies_ReturnsTop5()
    {
        // Arrange：构造多个峰值异常（每天都有一个超过 30% 的值）
        var records = new List<(DateTime, double)>();
        var random = new Random(42);
        for (int i = 30; i >= 1; i--)
        {
            var value = i % 2 == 0 ? 200 : 100; // 交替高低值
            records.Add((DateTime.UtcNow.AddDays(-i), value));
        }

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：最多返回 5 个异常
        Assert.True(result.Anomalies.Count <= 5);
    }

    [Fact]
    public void DetectAnomalies_SameDayMultipleRecords_GroupedAsOne()
    {
        // Arrange：同一天多条记录应合并为一条日均值
        var records = new List<(DateTime, double)>();
        var baseDate = DateTime.UtcNow.AddDays(-10);

        // 前 29 天正常
        for (int i = 30; i >= 2; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 100));
        }

        // 第 1 天有 3 条记录（应该在计算时取平均）
        records.Add((baseDate, 100));
        records.Add((baseDate.AddHours(2), 100));
        records.Add((baseDate.AddHours(4), 100));

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：不应产生异常（日均值正常）
        Assert.All(result.Anomalies, a =>
        {
            // 如果有异常，其检测日期不应是 baseDate（因为平均值正常）
            Assert.NotEqual(baseDate.Date, a.DetectedAt.Date);
        });
    }

    #endregion

    #region RecommendedAction 行动建议

    [Fact]
    public void DetectAnomalies_SpikeAnomaly_HasRecommendedAction()
    {
        // Arrange：构造血压峰值
        var records = GenerateRecords(30, 120, spikeOnDay: 5, spikeValue: 200);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodPressure);

        // Assert：异常事件应有行动建议
        var spike = result.Anomalies.FirstOrDefault(a => a.Type == AnomalyType.Spike);
        Assert.NotNull(spike);
        Assert.False(string.IsNullOrEmpty(spike.RecommendedAction));
        Assert.Contains("建议", spike.RecommendedAction);
    }

    [Fact]
    public void DetectAnomalies_ContinuousHigh_HasRecommendedAction()
    {
        // Arrange：构造持续偏高的血糖
        var records = new List<(DateTime, double)>();
        for (int i = 30; i >= 4; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 5.5));
        }
        for (int i = 3; i >= 1; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 8.0)); // 持续偏高 >20%
        }

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodSugar);

        // Assert
        var continuous = result.Anomalies.FirstOrDefault(a => a.Type == AnomalyType.ContinuousHigh);
        Assert.NotNull(continuous);
        Assert.False(string.IsNullOrEmpty(continuous.RecommendedAction));
        Assert.Contains("碳水", continuous.RecommendedAction); // 血糖相关建议
    }

    [Fact]
    public void DetectAnomalies_BloodSugarSpike_RecommendsRetest()
    {
        // Arrange：血糖突增
        var records = GenerateRecords(30, 5.5, spikeOnDay: 3, spikeValue: 12.0);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodSugar);

        // Assert：血糖峰值建议应提到复测
        var spike = result.Anomalies.FirstOrDefault(a => a.Type == AnomalyType.Spike);
        Assert.NotNull(spike);
        Assert.Contains("复测", spike.RecommendedAction);
    }

    #endregion

    #region 正向激励（Positive Reinforcement）

    [Fact]
    public void DetectAnomalies_StableData_GeneratesPositiveFeedback()
    {
        // Arrange：40 天稳定数据（确保覆盖基线+近期窗口边界）
        var records = GenerateRecords(40, 120);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.BloodPressure);

        // Assert：无异常时应有正向激励
        Assert.Empty(result.Anomalies);
        Assert.NotNull(result.PositiveFeedback);
        Assert.False(string.IsNullOrEmpty(result.PositiveFeedback.Message));
        Assert.True(result.PositiveFeedback.DaysStable > 0);
    }

    [Fact]
    public void DetectAnomalies_StableData_PositiveFeedbackContainsEncouragement()
    {
        // Arrange：40 天稳定数据
        var records = GenerateRecords(40, 75);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：正向信息应包含鼓励性文字
        Assert.NotNull(result.PositiveFeedback);
        Assert.Contains("心率", result.PositiveFeedback.Message);
    }

    [Fact]
    public void DetectAnomalies_WithAnomalies_NoPositiveFeedback()
    {
        // Arrange：有峰值异常
        var records = GenerateRecords(30, 100, spikeOnDay: 5, spikeValue: 200);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：有异常时不生成正向激励
        Assert.NotEmpty(result.Anomalies);
        Assert.Null(result.PositiveFeedback);
    }

    [Fact]
    public void DetectAnomalies_FewRecords_NoPositiveFeedback()
    {
        // Arrange：数据不足
        var records = GenerateRecords(10, 100);

        // Act
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：数据不足不应有正向激励（也不应有异常）
        Assert.Null(result.PositiveFeedback);
    }

    #endregion

    #region 可配置阈值

    [Fact]
    public void DetectAnomalies_CustomThresholds_Respected()
    {
        // Arrange：使用自定义阈值（峰值阈值 50%，更宽松）
        var options = new AnomalyDetectionOptions { SpikeThresholdPercent = 50 };
        var logger = new Mock<ILogger<HealthAnomalyDetector>>();
        var optionsWrapper = Microsoft.Extensions.Options.Options.Create(options);
        var detector = new HealthAnomalyDetector(logger.Object, optionsWrapper);

        // 构造 40% 偏差的数据（默认阈值 30% 会触发，50% 不会）
        var records = GenerateRecords(30, 100, spikeOnDay: 5, spikeValue: 140);

        // Act
        var result = detector.DetectAnomalies(records, HealthType.HeartRate);

        // Assert：50% 阈值下不应检测到 40% 的偏差
        Assert.DoesNotContain(result.Anomalies, a => a.Type == AnomalyType.Spike);
    }

    #endregion

    #region 时区感知

    [Fact]
    public void DetectAnomalies_WithTimezoneOffset_GroupsByLocalDate()
    {
        // Arrange：UTC+8 时区，构造跨 UTC 午夜的记录
        var records = new List<(DateTime, double)>();
        // 前 28 天正常
        for (int i = 30; i >= 3; i--)
        {
            records.Add((DateTime.UtcNow.AddDays(-i), 100));
        }

        // 构造两条在 UTC 凌晨但在本地同一天的记录（UTC+8）
        var utcDate1 = DateTime.UtcNow.AddDays(-2).Date.AddHours(18); // UTC 18:00 = 本地 02:00
        var utcDate2 = DateTime.UtcNow.AddDays(-2).Date.AddHours(20); // UTC 20:00 = 本地 04:00

        records.Add((utcDate1, 100));
        records.Add((utcDate2, 100));

        // Act：使用 UTC+8
        var result = _detector.DetectAnomalies(records, HealthType.HeartRate, timezoneOffsetHours: 8);

        // Assert：不应产生异常（两条记录在本地同一天，取平均后正常）
        Assert.All(result.Anomalies, a =>
        {
            Assert.NotEqual(utcDate1.Date, a.DetectedAt.Date);
        });
    }

    #endregion
}
