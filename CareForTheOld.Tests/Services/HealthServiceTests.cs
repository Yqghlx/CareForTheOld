using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// HealthService 单元测试
/// </summary>
public class HealthServiceTests
{
    private readonly AppDbContext _context;
    private readonly HealthService _service;

    public HealthServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _service = new HealthService(_context);
    }

    private async Task<Guid> CreateTestUserAsync()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800138000",
            PasswordHash = "test_hash",
            RealName = "老人测试",
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user.Id;
    }

    [Fact]
    public async Task CreateRecordAsync_ShouldCreateBloodPressureRecord_WhenValidRequest()
    {
        var userId = await CreateTestUserAsync();
        var request = new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        };

        var result = await _service.CreateRecordAsync(userId, request);

        result.Should().NotBeNull();
        result.Type.Should().Be(HealthType.BloodPressure);
        result.Systolic.Should().Be(120);
        result.Diastolic.Should().Be(80);
        result.UserId.Should().Be(userId);
    }

    [Fact]
    public async Task CreateRecordAsync_ShouldThrowException_WhenMissingRequiredData()
    {
        var userId = await CreateTestUserAsync();
        var request = new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure
            // 缺少收缩压和舒张压
        };

        var act = async () => await _service.CreateRecordAsync(userId, request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("血压记录需要填写收缩压和舒张压");
    }

    [Fact]
    public async Task GetUserRecordsAsync_ShouldReturnRecords_WhenRecordsExist()
    {
        var userId = await CreateTestUserAsync();

        // 创建多条记录
        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        });
        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.HeartRate,
            HeartRate = 72
        });

        var result = await _service.GetUserRecordsAsync(userId, null, 50);

        result.Should().HaveCount(2);
        result.Should().Contain(r => r.Type == HealthType.BloodPressure);
        result.Should().Contain(r => r.Type == HealthType.HeartRate);
    }

    [Fact]
    public async Task GetUserRecordsAsync_ShouldFilterByType_WhenTypeSpecified()
    {
        var userId = await CreateTestUserAsync();

        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        });
        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.HeartRate,
            HeartRate = 72
        });

        var result = await _service.GetUserRecordsAsync(userId, HealthType.BloodPressure, 50);

        result.Should().HaveCount(1);
        result[0].Type.Should().Be(HealthType.BloodPressure);
    }
}