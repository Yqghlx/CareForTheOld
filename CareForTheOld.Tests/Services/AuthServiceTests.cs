using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Auth;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// AuthService 单元测试
/// </summary>
public class AuthServiceTests
{
    private readonly AppDbContext _context;
    private readonly AuthService _service;
    private readonly Mock<IConfiguration> _mockConfig;

    public AuthServiceTests()
    {
        // 使用 InMemory 数据库
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);

        // Mock IConfiguration
        _mockConfig = new Mock<IConfiguration>();
        _mockConfig.Setup(c => c["Jwt:Key"]).Returns("CareForTheOld_DefaultSecretKey_2026_MustBe32Chars!");
        _mockConfig.Setup(c => c["Jwt:Issuer"]).Returns("CareForTheOld");
        _mockConfig.Setup(c => c["Jwt:Audience"]).Returns("CareForTheOld");
        _mockConfig.Setup(c => c["Jwt:AccessTokenExpirationMinutes"]).Returns("60");
        _mockConfig.Setup(c => c["Jwt:RefreshTokenExpirationDays"]).Returns("30");

        _service = new AuthService(_context, _mockConfig.Object);
    }

    [Fact]
    public async Task RegisterAsync_ShouldCreateUser_WhenValidRequest()
    {
        var request = new RegisterRequest
        {
            PhoneNumber = "13800138000",
            Password = "Test123!",
            RealName = "测试用户",
            Role = UserRole.Elder
        };

        var result = await _service.RegisterAsync(request);

        result.Should().NotBeNull();
        result.AccessToken.Should().NotBeEmpty();
        result.RefreshToken.Should().NotBeEmpty();
        result.User.PhoneNumber.Should().Be("13800138000");
        result.User.RealName.Should().Be("测试用户");
        result.User.Role.Should().Be(UserRole.Elder);
    }

    [Fact]
    public async Task RegisterAsync_ShouldThrowException_WhenPhoneNumberExists()
    {
        var request = new RegisterRequest
        {
            PhoneNumber = "13800138001",
            Password = "Test123!",
            RealName = "测试用户",
            Role = UserRole.Elder
        };

        await _service.RegisterAsync(request);

        var act = async () => await _service.RegisterAsync(request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("该手机号已注册");
    }

    [Fact]
    public async Task LoginAsync_ShouldReturnToken_WhenValidCredentials()
    {
        // 先注册用户
        var registerRequest = new RegisterRequest
        {
            PhoneNumber = "13800138002",
            Password = "Test123!",
            RealName = "测试用户",
            Role = UserRole.Child
        };
        await _service.RegisterAsync(registerRequest);

        // 登录
        var loginRequest = new LoginRequest
        {
            PhoneNumber = "13800138002",
            Password = "Test123!"
        };

        var result = await _service.LoginAsync(loginRequest);

        result.Should().NotBeNull();
        result.AccessToken.Should().NotBeEmpty();
        result.RefreshToken.Should().NotBeEmpty();
    }

    [Fact]
    public async Task LoginAsync_ShouldThrowException_WhenInvalidCredentials()
    {
        var loginRequest = new LoginRequest
        {
            PhoneNumber = "13800138003",
            Password = "WrongPassword"
        };

        var act = async () => await _service.LoginAsync(loginRequest);
        await act.Should().ThrowAsync<ArgumentException>();
    }
}