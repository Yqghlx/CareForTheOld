using System.Data.Common;
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
        var sevenDaysAgo = now.AddDays(-7);
        var thirtyDaysAgo = now.AddDays(-30);

        // 按类型聚合统计（一次 SQL 查询完成所有计算）
        const string sql = @"
            SELECT
                Type,
                COUNT(*) AS TotalCount,
                MAX(RecordedAt) AS LatestRecordedAt,
                (SELECT TOP 1 hr2.Systolic FROM HealthRecords hr2
                 WHERE hr2.UserId = @UserId AND hr2.Type = hr.Type AND hr2.IsDeleted = 0
                 ORDER BY hr2.RecordedAt DESC) AS LatestSystolic,
                (SELECT TOP 1 hr2.Diastolic FROM HealthRecords hr2
                 WHERE hr2.UserId = @UserId AND hr2.Type = hr.Type AND hr2.IsDeleted = 0
                 ORDER BY hr2.RecordedAt DESC) AS LatestDiastolic,
                (SELECT TOP 1 hr2.BloodSugar FROM HealthRecords hr2
                 WHERE hr2.UserId = @UserId AND hr2.Type = hr.Type AND hr2.IsDeleted = 0
                 ORDER BY hr2.RecordedAt DESC) AS LatestBloodSugar,
                (SELECT TOP 1 hr2.HeartRate FROM HealthRecords hr2
                 WHERE hr2.UserId = @UserId AND hr2.Type = hr.Type AND hr2.IsDeleted = 0
                 ORDER BY hr2.RecordedAt DESC) AS LatestHeartRate,
                (SELECT TOP 1 hr2.Temperature FROM HealthRecords hr2
                 WHERE hr2.UserId = @UserId AND hr2.Type = hr.Type AND hr2.IsDeleted = 0
                 ORDER BY hr2.RecordedAt DESC) AS LatestTemperature,
                AVG(CASE WHEN hr.RecordedAt >= @SevenDaysAgo THEN CAST(hr.Systolic AS FLOAT) END) AS Avg7Systolic,
                AVG(CASE WHEN hr.RecordedAt >= @SevenDaysAgo THEN CAST(hr.BloodSugar AS FLOAT) END) AS Avg7BloodSugar,
                AVG(CASE WHEN hr.RecordedAt >= @SevenDaysAgo THEN CAST(hr.HeartRate AS FLOAT) END) AS Avg7HeartRate,
                AVG(CASE WHEN hr.RecordedAt >= @SevenDaysAgo THEN CAST(hr.Temperature AS FLOAT) END) AS Avg7Temperature,
                AVG(CASE WHEN hr.RecordedAt >= @ThirtyDaysAgo THEN CAST(hr.Systolic AS FLOAT) END) AS Avg30Systolic,
                AVG(CASE WHEN hr.RecordedAt >= @ThirtyDaysAgo THEN CAST(hr.BloodSugar AS FLOAT) END) AS Avg30BloodSugar,
                AVG(CASE WHEN hr.RecordedAt >= @ThirtyDaysAgo THEN CAST(hr.HeartRate AS FLOAT) END) AS Avg30HeartRate,
                AVG(CASE WHEN hr.RecordedAt >= @ThirtyDaysAgo THEN CAST(hr.Temperature AS FLOAT) END) AS Avg30Temperature
            FROM HealthRecords hr
            WHERE hr.UserId = @UserId AND hr.IsDeleted = 0
            GROUP BY hr.Type";

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

            stats.Add(statsResponse);
        }

        return stats;
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
        HealthType.BloodPressure => "血压",
        HealthType.BloodSugar => "血糖",
        HealthType.HeartRate => "心率",
        HealthType.Temperature => "体温",
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
