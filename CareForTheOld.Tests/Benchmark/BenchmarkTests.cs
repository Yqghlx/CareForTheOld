using System.Diagnostics;
using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Tests.Benchmark;

/// <summary>
/// 性能基准测试
/// 使用 Stopwatch 断言操作耗时不超过阈值
/// </summary>
public class BenchmarkTests
{
    private AppDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        return new AppDbContext(options);
    }

    /// <summary>
    /// 批量插入 100 条健康记录应在 5 秒内完成
    /// </summary>
    [Fact]
    public async Task BatchInsert_100HealthRecords_ShouldCompleteWithin5Seconds()
    {
        var context = CreateContext();
        var userId = Guid.NewGuid();
        context.Users.Add(new User
        {
            Id = userId,
            PhoneNumber = "13900880001",
            PasswordHash = "hash",
            RealName = "性能老人",
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        });
        await context.SaveChangesAsync();

        var sw = Stopwatch.StartNew();

        for (int i = 0; i < 100; i++)
        {
            context.HealthRecords.Add(new HealthRecord
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = HealthType.BloodPressure,
                Systolic = 100 + (i % 40),
                Diastolic = 60 + (i % 20),
                RecordedAt = DateTime.UtcNow.AddMinutes(-i),
                CreatedAt = DateTime.UtcNow
            });
        }
        await context.SaveChangesAsync();

        sw.Stop();
        sw.Elapsed.Should().BeLessThan(TimeSpan.FromSeconds(5));
    }

    /// <summary>
    /// 批量插入 1000 条位置记录应在 10 秒内完成
    /// </summary>
    [Fact]
    public async Task BatchInsert_1000LocationRecords_ShouldCompleteWithin10Seconds()
    {
        var context = CreateContext();
        var userId = Guid.NewGuid();
        context.Users.Add(new User
        {
            Id = userId,
            PhoneNumber = "13900880002",
            PasswordHash = "hash",
            RealName = "性能老人2",
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        });
        await context.SaveChangesAsync();

        var sw = Stopwatch.StartNew();

        for (int i = 0; i < 1000; i++)
        {
            context.LocationRecords.Add(new LocationRecord
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Latitude = 39.9 + (i * 0.0001),
                Longitude = 116.3 + (i * 0.0001),
                RecordedAt = DateTime.UtcNow.AddSeconds(-i)
            });
        }
        await context.SaveChangesAsync();

        sw.Stop();
        sw.Elapsed.Should().BeLessThan(TimeSpan.FromSeconds(10));
    }

    /// <summary>
    /// 大数据量统计查询应在 2 秒内完成
    /// </summary>
    [Fact]
    public async Task StatsQuery_With500Records_ShouldCompleteWithin2Seconds()
    {
        var context = CreateContext();
        var userId = Guid.NewGuid();
        context.Users.Add(new User
        {
            Id = userId,
            PhoneNumber = "13900880003",
            PasswordHash = "hash",
            RealName = "统计老人",
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        });
        await context.SaveChangesAsync();

        // 准备数据
        var types = new[] { HealthType.BloodPressure, HealthType.BloodSugar, HealthType.HeartRate, HealthType.Temperature };
        for (int i = 0; i < 500; i++)
        {
            var type = types[i % 4];
            var record = new HealthRecord
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = type,
                RecordedAt = DateTime.UtcNow.AddDays(-i),
                CreatedAt = DateTime.UtcNow
            };
            switch (type)
            {
                case HealthType.BloodPressure:
                    record.Systolic = 120 + (i % 20);
                    record.Diastolic = 80 + (i % 10);
                    break;
                case HealthType.BloodSugar:
                    record.BloodSugar = 5.0m + (i % 30) * 0.1m;
                    break;
                case HealthType.HeartRate:
                    record.HeartRate = 60 + (i % 30);
                    break;
                case HealthType.Temperature:
                    record.Temperature = 36.0m + (i % 10) * 0.1m;
                    break;
            }
            context.HealthRecords.Add(record);
        }
        await context.SaveChangesAsync();

        // 测试查询性能（InMemory 模式下先拉取再内存分组）
        var sw = Stopwatch.StartNew();
        var allRecords = await context.HealthRecords
            .Where(r => r.UserId == userId && !r.IsDeleted)
            .ToListAsync();
        var groups = allRecords.GroupBy(r => r.Type).ToList();
        sw.Stop();

        sw.Elapsed.Should().BeLessThan(TimeSpan.FromSeconds(2));
        groups.Should().HaveCount(4, "应有4种健康类型的数据");
    }
}
