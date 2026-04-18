using Bogus;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Auth;
using CareForTheOld.Models.DTOs.Requests.Health;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Moq;

namespace CareForTheOld.Tests.Fuzz;

/// <summary>
/// 输入验证模糊测试
/// 使用 Bogus 生成大量随机畸形数据，验证服务层不抛未处理异常
/// </summary>
public class InputValidationFuzzTests
{
    private readonly AppDbContext _context;
    private readonly AuthService _authService;
    private readonly HealthService _healthService;

    public InputValidationFuzzTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);

        var mockConfig = new Mock<IConfiguration>();
        mockConfig.Setup(c => c["Jwt:Key"]).Returns("CareForTheOld_FuzzTestSecretKey_2026_32Chars!");
        mockConfig.Setup(c => c["Jwt:Issuer"]).Returns("CareForTheOld");
        mockConfig.Setup(c => c["Jwt:Audience"]).Returns("CareForTheOld");
        mockConfig.Setup(c => c["Jwt:AccessTokenExpirationMinutes"]).Returns("60");
        mockConfig.Setup(c => c["Jwt:RefreshTokenExpirationDays"]).Returns("30");

        _authService = new AuthService(_context, mockConfig.Object);
        _healthService = new HealthService(_context, new Mock<IHealthAlertService>().Object);
    }

    /// <summary>
    /// 随机畸形手机号注册不应抛未处理异常
    /// </summary>
    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("abc")]
    [InlineData("12345")]
    [InlineData("abcdefghijklmnopqrstuvwxyz")]
    [InlineData("<script>alert(1)</script>")]
    [InlineData("'; DROP TABLE Users;--")]
    [InlineData("13900001111")]  // 正常格式但会重复
    [InlineData("+86-139-0000-1111")]
    [InlineData("十三亿八千万")]
    [InlineData("139000011119999999")]
    public async Task RegisterAsync_ShouldNotThrowUnhandled_WithFuzzPhoneNumbers(string phone)
    {
        // 每次用新 context 避免冲突
        var request = new RegisterRequest
        {
            PhoneNumber = phone,
            Password = "Test1234",
            RealName = "模糊测试",
            BirthDate = DateOnly.FromDateTime(DateTime.UtcNow.AddYears(-70)),
            Role = UserRole.Elder
        };

        // 不应抛未处理异常（ArgumentException / InvalidOperationException 是预期的）
        try
        {
            await _authService.RegisterAsync(request);
        }
        catch (ArgumentException)
        {
            // 预期的验证异常，正常
        }
        catch (InvalidOperationException)
        {
            // 预期的业务异常，正常
        }
    }

    /// <summary>
    /// 随机畸形密码注册不应抛未处理异常
    /// </summary>
    [Theory]
    [InlineData("")]
    [InlineData("12345678")]
    [InlineData("abcdefgh")]
    [InlineData("!@#$%^&*")]
    [InlineData("a1")]
    [InlineData("   ")]
    public async Task RegisterAsync_ShouldNotThrowUnhandled_WithFuzzPasswords(string password)
    {
        var request = new RegisterRequest
        {
            PhoneNumber = $"139{Random.Shared.Next(10000000, 99999999)}",
            Password = password,
            RealName = "模糊测试",
            BirthDate = DateOnly.FromDateTime(DateTime.UtcNow.AddYears(-70)),
            Role = UserRole.Elder
        };

        try
        {
            await _authService.RegisterAsync(request);
        }
        catch (ArgumentException) { }
        catch (InvalidOperationException) { }
    }

    /// <summary>
    /// 超出范围的血压值不应抛未处理异常
    /// </summary>
    [Theory]
    [InlineData(0, 0)]
    [InlineData(-10, -5)]
    [InlineData(999, 999)]
    [InlineData(int.MinValue, int.MaxValue)]
    [InlineData(120, -1)]
    [InlineData(-1, 80)]
    public async Task CreateRecordAsync_ShouldNotThrowUnhandled_WithFuzzBloodPressure(int systolic, int diastolic)
    {
        var userId = Guid.NewGuid();
        _context.Users.Add(new Models.Entities.User
        {
            Id = userId,
            PhoneNumber = $"139{Random.Shared.Next(10000000, 99999999)}",
            PasswordHash = "hash",
            RealName = "血压模糊",
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        var request = new CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = systolic,
            Diastolic = diastolic
        };

        try
        {
            await _healthService.CreateRecordAsync(userId, request);
        }
        catch (ArgumentException) { }
    }

    /// <summary>
    /// 超出范围的血糖/心率/体温值不应抛未处理异常
    /// </summary>
    [Theory]
    [InlineData(HealthType.BloodSugar, -1.0)]
    [InlineData(HealthType.BloodSugar, 999.0)]
    [InlineData(HealthType.HeartRate, -10)]
    [InlineData(HealthType.HeartRate, 0)]
    [InlineData(HealthType.HeartRate, 999)]
    [InlineData(HealthType.Temperature, 20.0)]
    [InlineData(HealthType.Temperature, 50.0)]
    [InlineData(HealthType.Temperature, -5.0)]
    public async Task CreateRecordAsync_ShouldNotThrowUnhandled_WithFuzzHealthValues(HealthType type, double value)
    {
        var userId = Guid.NewGuid();
        _context.Users.Add(new Models.Entities.User
        {
            Id = userId,
            PhoneNumber = $"139{Random.Shared.Next(10000000, 99999999)}",
            PasswordHash = "hash",
            RealName = "健康模糊",
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        var request = new CreateHealthRecordRequest { Type = type };
        switch (type)
        {
            case HealthType.BloodSugar:
                request.BloodSugar = (decimal)value;
                break;
            case HealthType.HeartRate:
                request.HeartRate = (int)value;
                break;
            case HealthType.Temperature:
                request.Temperature = (decimal)value;
                break;
        }

        try
        {
            await _healthService.CreateRecordAsync(userId, request);
        }
        catch (ArgumentException) { }
    }

    /// <summary>
    /// Bogus 批量随机输入测试（100 组随机手机号）
    /// </summary>
    [Fact]
    public async Task RegisterAsync_ShouldHandleBatchRandomInputs()
    {
        var faker = new Faker("zh_CN");

        for (int i = 0; i < 100; i++)
        {
            var request = new RegisterRequest
            {
                PhoneNumber = faker.Random.String2(11, "0123456789abcDEF!@# "),
                Password = faker.Internet.Password(12),
                RealName = faker.Name.FullName(),
                BirthDate = DateOnly.FromDateTime(faker.Date.Past(80, DateTime.UtcNow.AddYears(-60))),
                Role = faker.Random.Enum<UserRole>()
            };

            try
            {
                await _authService.RegisterAsync(request);
            }
            catch (ArgumentException) { }
            catch (InvalidOperationException) { }
            // 任何其他异常都不应发生，否则测试将失败
        }

        // 如果能走到这里，说明所有畸形输入都没有导致未处理异常
        true.Should().BeTrue("100 组随机输入均未产生未处理异常");
    }
}
