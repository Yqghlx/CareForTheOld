using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// HealthAlertService 单元测试
/// </summary>
public class HealthAlertServiceTests
{
    private readonly AppDbContext _context;
    private readonly Mock<INotificationService> _mockNotificationService;
    private readonly HealthAlertService _service;

    public HealthAlertServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _mockNotificationService = new Mock<INotificationService>();
        _service = new HealthAlertService(_context, _mockNotificationService.Object, new Mock<IFamilyService>().Object, NullLogger<HealthAlertService>.Instance);
    }

    private async Task<Guid> CreateTestUserAsync(string realName = "测试老人", UserRole role = UserRole.Elder)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800138000",
            PasswordHash = "test_hash",
            RealName = realName,
            Role = role,
            CreatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user.Id;
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnNull_WhenBloodPressureIsNormal()
    {
        var record = new HealthRecord
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        };

        var result = _service.CheckAbnormal(record);

        result.Should().BeNull();
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnWarning_WhenBloodPressureIsHigh()
    {
        var record = new HealthRecord
        {
            Type = HealthType.BloodPressure,
            Systolic = 150,
            Diastolic = 95
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("血压偏高");
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnCriticalWarning_WhenBloodPressureIsVeryHigh()
    {
        var record = new HealthRecord
        {
            Type = HealthType.BloodPressure,
            Systolic = 180,
            Diastolic = 120
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("立即就医");
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnNull_WhenBloodSugarIsNormal()
    {
        var record = new HealthRecord
        {
            Type = HealthType.BloodSugar,
            BloodSugar = 5.5m
        };

        var result = _service.CheckAbnormal(record);

        result.Should().BeNull();
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnWarning_WhenBloodSugarIsHigh()
    {
        var record = new HealthRecord
        {
            Type = HealthType.BloodSugar,
            BloodSugar = 8.0m
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("血糖偏高");
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnCriticalWarning_WhenBloodSugarIsVeryHigh()
    {
        var record = new HealthRecord
        {
            Type = HealthType.BloodSugar,
            BloodSugar = 12.0m
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("立即就医");
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnNull_WhenHeartRateIsNormal()
    {
        var record = new HealthRecord
        {
            Type = HealthType.HeartRate,
            HeartRate = 75
        };

        var result = _service.CheckAbnormal(record);

        result.Should().BeNull();
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnWarning_WhenHeartRateIsHigh()
    {
        var record = new HealthRecord
        {
            Type = HealthType.HeartRate,
            HeartRate = 110
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("心率偏快");
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnNull_WhenTemperatureIsNormal()
    {
        var record = new HealthRecord
        {
            Type = HealthType.Temperature,
            Temperature = 36.5m
        };

        var result = _service.CheckAbnormal(record);

        result.Should().BeNull();
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnWarning_WhenTemperatureIsHigh()
    {
        var record = new HealthRecord
        {
            Type = HealthType.Temperature,
            Temperature = 38.5m
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("发烧");
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnCriticalWarning_WhenTemperatureIsVeryHigh()
    {
        var record = new HealthRecord
        {
            Type = HealthType.Temperature,
            Temperature = 39.5m
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("高烧");
        result.Should().Contain("立即就医");
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnWarning_WhenBloodPressureIsLow()
    {
        var record = new HealthRecord
        {
            Type = HealthType.BloodPressure,
            Systolic = 85,
            Diastolic = 55
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("血压偏低");
    }

    [Fact]
    public void CheckAbnormal_ShouldReturnWarning_WhenBloodSugarIsLow()
    {
        var record = new HealthRecord
        {
            Type = HealthType.BloodSugar,
            BloodSugar = 3.5m
        };

        var result = _service.CheckAbnormal(record);

        result.Should().NotBeNull();
        result.Should().Contain("血糖偏低");
    }
}