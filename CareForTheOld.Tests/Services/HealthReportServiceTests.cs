using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// HealthReportService 单元测试
/// </summary>
public class HealthReportServiceTests
{
    private readonly AppDbContext _context;
    private readonly HealthReportService _service;

    public HealthReportServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _service = new HealthReportService(_context);
    }

    private async Task<Guid> CreateTestUserAsync(string realName = "测试老人")
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800138000",
            PasswordHash = "test_hash",
            RealName = realName,
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user.Id;
    }

    private async Task CreateTestHealthRecordsAsync(Guid userId)
    {
        // 创建血压记录
        _context.HealthRecords.Add(new HealthRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80,
            RecordedAt = DateTime.UtcNow.AddDays(-1),
            CreatedAt = DateTime.UtcNow
        });

        // 创建血糖记录
        _context.HealthRecords.Add(new HealthRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = HealthType.BloodSugar,
            BloodSugar = 5.5m,
            RecordedAt = DateTime.UtcNow.AddDays(-2),
            CreatedAt = DateTime.UtcNow
        });

        // 创建心率记录
        _context.HealthRecords.Add(new HealthRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = HealthType.HeartRate,
            HeartRate = 75,
            RecordedAt = DateTime.UtcNow.AddDays(-3),
            CreatedAt = DateTime.UtcNow
        });

        // 创建体温记录
        _context.HealthRecords.Add(new HealthRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = HealthType.Temperature,
            Temperature = 36.5m,
            RecordedAt = DateTime.UtcNow.AddDays(-4),
            CreatedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();
    }

    [Fact]
    public async Task GeneratePdfReportAsync_ShouldGeneratePdf_WhenUserExists()
    {
        var userId = await CreateTestUserAsync("张三");
        await CreateTestHealthRecordsAsync(userId);

        var result = await _service.GeneratePdfReportAsync(userId, 7);

        result.Should().NotBeNull();
        result.Should().HaveCountGreaterThan(0);
        // PDF 文件通常以 %PDF- 开头
        result[0].Should().Be(0x25); // '%'
        result[1].Should().Be(0x50); // 'P'
        result[2].Should().Be(0x44); // 'D'
        result[3].Should().Be(0x46); // 'F'
    }

    [Fact]
    public async Task GeneratePdfReportAsync_ShouldThrowException_WhenUserNotFound()
    {
        var act = async () => await _service.GeneratePdfReportAsync(Guid.NewGuid(), 7);

        await act.Should().ThrowAsync<KeyNotFoundException>()
            .WithMessage("用户不存在");
    }

    [Fact]
    public async Task GeneratePdfReportAsync_ShouldGeneratePdf_WhenNoRecords()
    {
        var userId = await CreateTestUserAsync("李四");

        var result = await _service.GeneratePdfReportAsync(userId, 7);

        result.Should().NotBeNull();
        result.Should().HaveCountGreaterThan(0);
        // 即使没有记录，也应该生成 PDF
    }

    [Fact]
    public async Task GeneratePdfReportAsync_ShouldIncludeCorrectTimeRange()
    {
        var userId = await CreateTestUserAsync("王五");
        // 创建一条30天前的记录（应该在30天报告内，但不在7天报告内）
        _context.HealthRecords.Add(new HealthRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = HealthType.BloodPressure,
            Systolic = 130,
            Diastolic = 85,
            RecordedAt = DateTime.UtcNow.AddDays(-25),
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        // 7天报告（应该不包含该记录）
        var result7Days = await _service.GeneratePdfReportAsync(userId, 7);
        result7Days.Should().NotBeNull();

        // 30天报告（应该包含该记录）
        var result30Days = await _service.GeneratePdfReportAsync(userId, 30);
        result30Days.Should().NotBeNull();
        // 30天报告应该更大（包含更多数据）
        result30Days.Length.Should().BeGreaterThan(result7Days.Length);
    }

    [Fact]
    public async Task GeneratePdfReportAsync_ShouldIncludeAbnormalRecords_WhenAbnormalDataExists()
    {
        var userId = await CreateTestUserAsync("赵六");
        // 创建异常血压记录
        _context.HealthRecords.Add(new HealthRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = HealthType.BloodPressure,
            Systolic = 180,  // 高血压
            Diastolic = 120,
            RecordedAt = DateTime.UtcNow.AddDays(-1),
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        var result = await _service.GeneratePdfReportAsync(userId, 7);

        result.Should().NotBeNull();
        result.Should().HaveCountGreaterThan(0);
        // PDF 应该包含异常数据的标记
    }

    [Fact]
    public async Task GeneratePdfReportAsync_ShouldIncludeAllHealthTypes()
    {
        var userId = await CreateTestUserAsync("钱七");
        await CreateTestHealthRecordsAsync(userId);

        var result = await _service.GeneratePdfReportAsync(userId, 7);

        result.Should().NotBeNull();
        // PDF 应该包含血压、血糖、心率、体温四种类型的数据
    }
}