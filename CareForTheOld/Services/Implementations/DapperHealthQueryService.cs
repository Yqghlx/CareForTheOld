using System.Data.Common;
using CareForTheOld.Common.Constants;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Dapper;
using Microsoft.Extensions.Configuration;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 健康数据只读查询服务（Dapper 实现）
///
/// 使用原生 SQL 实现高频聚合查询，避免 EF Core 的变更追踪和表达式树编译开销。
/// 对于 GroupBy + 多字段聚合的场景，原生 SQL 性能优势显著。
///
/// 数据库连接通过 IConfiguration 动态创建，兼容 SQLite（开发）和 PostgreSQL（生产）。
/// </summary>
public class DapperHealthQueryService : IHealthQueryService
{
    private readonly IConfiguration _configuration;

    public DapperHealthQueryService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    /// <inheritdoc />
    public async Task<List<HealthStatsResponse>> GetUserStatsAsync(Guid userId)
    {
        var connectionString = _configuration.GetConnectionString("DefaultConnection")
            ?? "Data Source=carefortheold.db";

        using var connection = CreateConnection(connectionString);
        await connection.OpenAsync();

        var now = DateTime.UtcNow;
        var sevenDaysAgo = now.AddDays(-AppConstants.HealthStatsDays.RecentDays);
        var thirtyDaysAgo = now.AddDays(-AppConstants.HealthStatsDays.LongTermDays);

        // 按类型聚合统计（一次 SQL 查询完成所有计算）
        // 使用 LIMIT 1 代替 TOP 1，兼容 SQLite 和 PostgreSQL
        const string sql = @"
            SELECT
                ""Type"",
                COUNT(*) AS TotalCount,
                MAX(""RecordedAt"") AS LatestRecordedAt,
                (SELECT hr2.""Systolic"" FROM ""HealthRecords"" hr2
                 WHERE hr2.""UserId"" = @UserId AND hr2.""Type"" = hr.""Type"" AND hr2.""IsDeleted"" = false
                 ORDER BY hr2.""RecordedAt"" DESC LIMIT 1) AS LatestSystolic,
                (SELECT hr2.""Diastolic"" FROM ""HealthRecords"" hr2
                 WHERE hr2.""UserId"" = @UserId AND hr2.""Type"" = hr.""Type"" AND hr2.""IsDeleted"" = false
                 ORDER BY hr2.""RecordedAt"" DESC LIMIT 1) AS LatestDiastolic,
                (SELECT hr2.""BloodSugar"" FROM ""HealthRecords"" hr2
                 WHERE hr2.""UserId"" = @UserId AND hr2.""Type"" = hr.""Type"" AND hr2.""IsDeleted"" = false
                 ORDER BY hr2.""RecordedAt"" DESC LIMIT 1) AS LatestBloodSugar,
                (SELECT hr2.""HeartRate"" FROM ""HealthRecords"" hr2
                 WHERE hr2.""UserId"" = @UserId AND hr2.""Type"" = hr.""Type"" AND hr2.""IsDeleted"" = false
                 ORDER BY hr2.""RecordedAt"" DESC LIMIT 1) AS LatestHeartRate,
                (SELECT hr2.""Temperature"" FROM ""HealthRecords"" hr2
                 WHERE hr2.""UserId"" = @UserId AND hr2.""Type"" = hr.""Type"" AND hr2.""IsDeleted"" = false
                 ORDER BY hr2.""RecordedAt"" DESC LIMIT 1) AS LatestTemperature,
                AVG(CASE WHEN hr.""RecordedAt"" >= @SevenDaysAgo THEN CAST(hr.""Systolic"" AS FLOAT) END) AS Avg7Systolic,
                AVG(CASE WHEN hr.""RecordedAt"" >= @SevenDaysAgo THEN CAST(hr.""BloodSugar"" AS FLOAT) END) AS Avg7BloodSugar,
                AVG(CASE WHEN hr.""RecordedAt"" >= @SevenDaysAgo THEN CAST(hr.""HeartRate"" AS FLOAT) END) AS Avg7HeartRate,
                AVG(CASE WHEN hr.""RecordedAt"" >= @SevenDaysAgo THEN CAST(hr.""Temperature"" AS FLOAT) END) AS Avg7Temperature,
                AVG(CASE WHEN hr.""RecordedAt"" >= @ThirtyDaysAgo THEN CAST(hr.""Systolic"" AS FLOAT) END) AS Avg30Systolic,
                AVG(CASE WHEN hr.""RecordedAt"" >= @ThirtyDaysAgo THEN CAST(hr.""BloodSugar"" AS FLOAT) END) AS Avg30BloodSugar,
                AVG(CASE WHEN hr.""RecordedAt"" >= @ThirtyDaysAgo THEN CAST(hr.""HeartRate"" AS FLOAT) END) AS Avg30HeartRate,
                AVG(CASE WHEN hr.""RecordedAt"" >= @ThirtyDaysAgo THEN CAST(hr.""Temperature"" AS FLOAT) END) AS Avg30Temperature
            FROM ""HealthRecords"" hr
            WHERE hr.""UserId"" = @UserId AND hr.""IsDeleted"" = false
            GROUP BY hr.""Type""";

        var rows = await connection.QueryAsync<HealthStatsRow>(sql, new
        {
            UserId = userId,
            SevenDaysAgo = sevenDaysAgo,
            ThirtyDaysAgo = thirtyDaysAgo
        });

        var stats = new List<HealthStatsResponse>();

        foreach (var row in rows)
        {
            var healthType = (HealthType)row.Type;
            var statsResponse = new HealthStatsResponse
            {
                TypeName = GetTypeDisplayName(healthType),
                TotalCount = row.TotalCount,
                LatestRecordedAt = row.LatestRecordedAt
            };

            switch (healthType)
            {
                case HealthType.BloodPressure:
                    statsResponse.LatestValue = row.LatestSystolic;
                    statsResponse.Average7Days = row.Avg7Systolic.HasValue ? (decimal)Math.Round(row.Avg7Systolic.Value, 1) : null;
                    statsResponse.Average30Days = row.Avg30Systolic.HasValue ? (decimal)Math.Round(row.Avg30Systolic.Value, 1) : null;
                    break;
                case HealthType.BloodSugar:
                    statsResponse.LatestValue = row.LatestBloodSugar;
                    statsResponse.Average7Days = row.Avg7BloodSugar.HasValue ? (decimal)Math.Round(row.Avg7BloodSugar.Value, 1) : null;
                    statsResponse.Average30Days = row.Avg30BloodSugar.HasValue ? (decimal)Math.Round(row.Avg30BloodSugar.Value, 1) : null;
                    break;
                case HealthType.HeartRate:
                    statsResponse.LatestValue = row.LatestHeartRate;
                    statsResponse.Average7Days = row.Avg7HeartRate.HasValue ? (decimal)Math.Round(row.Avg7HeartRate.Value, 1) : null;
                    statsResponse.Average30Days = row.Avg30HeartRate.HasValue ? (decimal)Math.Round(row.Avg30HeartRate.Value, 1) : null;
                    break;
                case HealthType.Temperature:
                    statsResponse.LatestValue = row.LatestTemperature;
                    statsResponse.Average7Days = row.Avg7Temperature.HasValue ? (decimal)Math.Round(row.Avg7Temperature.Value, 1) : null;
                    statsResponse.Average30Days = row.Avg30Temperature.HasValue ? (decimal)Math.Round(row.Avg30Temperature.Value, 1) : null;
                    break;
            }

            // 计算趋势：7天均值 vs 30天均值
            ComputeTrend(statsResponse, healthType);

            stats.Add(statsResponse);
        }

        return stats;
    }

    /// <summary>
    /// 计算健康趋势：7天均值 vs 30天均值
    /// 当7天均值相对30天均值变化超过阈值时标记趋势方向并生成预警提示
    /// </summary>
    private static void ComputeTrend(HealthStatsResponse stats, HealthType type)
    {
        if (!stats.Average7Days.HasValue || !stats.Average30Days.HasValue || stats.Average30Days.Value == 0)
            return;

        var diff = (double)(stats.Average7Days.Value - stats.Average30Days.Value);
        var percentChange = Math.Abs(diff / (double)stats.Average30Days.Value * 100);

        // 不同健康类型使用不同的变化阈值
        var threshold = type switch
        {
            HealthType.BloodPressure => 8.0,   // 血压波动 8% 以上关注
            HealthType.BloodSugar => 10.0,      // 血糖波动 10% 以上关注
            HealthType.HeartRate => 10.0,        // 心率波动 10% 以上关注
            HealthType.Temperature => 1.0,       // 体温变化 1% 以上关注（体温基数小，1%约0.36度）
            _ => 10.0
        };

        if (percentChange < threshold)
        {
            stats.Trend = "stable";
            return;
        }

        var typeName = GetTypeDisplayName(type);
        var percentStr = Math.Round(percentChange, 1);

        if (diff > 0)
        {
            stats.Trend = "rising";
            stats.TrendWarning = $"近7天{typeName}均值较30天均值升高约{percentStr}%，请关注";
        }
        else
        {
            stats.Trend = "falling";
            stats.TrendWarning = $"近7天{typeName}均值较30天均值降低约{percentStr}%，请关注";
        }
    }

    /// <summary>
    /// 根据连接字符串创建对应的数据库连接
    /// </summary>
    private static DbConnection CreateConnection(string connectionString)
    {
        if (connectionString.Contains("Host=") || connectionString.Contains("Server="))
        {
            return new Npgsql.NpgsqlConnection(connectionString);
        }
        return new Microsoft.Data.Sqlite.SqliteConnection(connectionString);
    }

    private static string GetTypeDisplayName(HealthType type) => type switch
    {
        HealthType.BloodPressure => AppConstants.HealthTypeLabels.BloodPressure,
        HealthType.BloodSugar => AppConstants.HealthTypeLabels.BloodSugar,
        HealthType.HeartRate => AppConstants.HealthTypeLabels.HeartRate,
        HealthType.Temperature => AppConstants.HealthTypeLabels.Temperature,
        _ => type.ToString()
    };

    /// <summary>
    /// Dapper 查询结果行 DTO（强类型，替代 dynamic 避免 AOT 警告）
    /// </summary>
    private class HealthStatsRow
    {
        public int Type { get; set; }
        public int TotalCount { get; set; }
        public DateTime LatestRecordedAt { get; set; }
        public int? LatestSystolic { get; set; }
        public int? LatestDiastolic { get; set; }
        public decimal? LatestBloodSugar { get; set; }
        public int? LatestHeartRate { get; set; }
        public decimal? LatestTemperature { get; set; }
        public double? Avg7Systolic { get; set; }
        public double? Avg7BloodSugar { get; set; }
        public double? Avg7HeartRate { get; set; }
        public double? Avg7Temperature { get; set; }
        public double? Avg30Systolic { get; set; }
        public double? Avg30BloodSugar { get; set; }
        public double? Avg30HeartRate { get; set; }
        public double? Avg30Temperature { get; set; }
    }
}
