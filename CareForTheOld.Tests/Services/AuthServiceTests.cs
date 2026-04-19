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

    [Fact]
    public async Task RefreshTokenAsync_ShouldReturnNewToken_WhenValidToken()
    {
        // 注册获取 token
        var registerResult = await _service.RegisterAsync(new RegisterRequest
        {
            PhoneNumber = "13900007001", Password = "Test1234", RealName = "刷新测试", Role = UserRole.Elder
        });
        // 刷新
        var result = await _service.RefreshTokenAsync(registerResult.RefreshToken);
        result.Should().NotBeNull();
        result.AccessToken.Should().NotBeEmpty();
        result.RefreshToken.Should().NotBe(registerResult.RefreshToken);
    }

    [Fact]
    public async Task RefreshTokenAsync_ShouldThrow_WhenTokenExpired()
    {
        // 手动创建一个过期的 token
        var user = new User { Id = Guid.NewGuid(), PhoneNumber = "13900007002", PasswordHash = "hash", RealName = "过期测试", Role = UserRole.Elder, CreatedAt = DateTime.UtcNow };
        _context.Users.Add(user);
        var token = new RefreshToken { Id = Guid.NewGuid(), UserId = user.Id, Token = "expired_token", ExpiresAt = DateTime.UtcNow.AddDays(-1), IsRevoked = false, IsUsed = false, CreatedAt = DateTime.UtcNow };
        _context.RefreshTokens.Add(token);
        await _context.SaveChangesAsync();
        var act = async () => await _service.RefreshTokenAsync("expired_token");
        await act.Should().ThrowAsync<ArgumentException>().WithMessage("刷新令牌已过期或已撤销");
    }

    [Fact]
    public async Task RefreshTokenAsync_ShouldThrow_WhenTokenReplayed()
    {
        var registerResult = await _service.RegisterAsync(new RegisterRequest
        {
            PhoneNumber = "13900007003", Password = "Test1234", RealName = "重放测试", Role = UserRole.Elder
        });
        // 第一次刷新成功
        await _service.RefreshTokenAsync(registerResult.RefreshToken);
        // 第二次重放 → 应吊销全部 token 并抛异常
        var act = async () => await _service.RefreshTokenAsync(registerResult.RefreshToken);
        await act.Should().ThrowAsync<ArgumentException>().WithMessage("检测到安全异常，请重新登录");
    }

    [Fact]
    public async Task RefreshTokenAsync_ShouldThrow_WhenTokenNotFound()
    {
        var act = async () => await _service.RefreshTokenAsync("nonexistent_token");
        await act.Should().ThrowAsync<ArgumentException>().WithMessage("无效的刷新令牌");
    }

    [Fact]
    public async Task RefreshTokenAsync_ShouldMarkOldTokenAsUsedAndRevoked()
    {
        // 注册获取 token
        var registerResult = await _service.RegisterAsync(new RegisterRequest
        {
            PhoneNumber = "13900007004", Password = "Test1234", RealName = "轮换验证", Role = UserRole.Elder
        });

        // 刷新
        await _service.RefreshTokenAsync(registerResult.RefreshToken);

        // 验证旧 Token 已标记为已使用和已撤销
        var oldToken = await _context.RefreshTokens
            .FirstOrDefaultAsync(t => t.Token == registerResult.RefreshToken);
        oldToken.Should().NotBeNull();
        oldToken!.IsUsed.Should().BeTrue();
        oldToken.IsRevoked.Should().BeTrue();
    }

    [Fact]
    public async Task RefreshTokenAsync_ShouldCleanupExpiredTokens()
    {
        // 注册用户
        var registerResult = await _service.RegisterAsync(new RegisterRequest
        {
            PhoneNumber = "13900007005", Password = "Test1234", RealName = "清理测试", Role = UserRole.Elder
        });

        // 手动添加一个已过期的旧 Token
        var expiredToken = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = registerResult.User.Id,
            Token = "old_expired_token",
            ExpiresAt = DateTime.UtcNow.AddDays(-10),
            IsRevoked = false,
            IsUsed = false,
            CreatedAt = DateTime.UtcNow.AddDays(-30)
        };
        _context.RefreshTokens.Add(expiredToken);
        await _context.SaveChangesAsync();

        // 使用有效 Token 刷新（触发清理）
        await _service.RefreshTokenAsync(registerResult.RefreshToken);

        // 过期 Token 应已被清理
        var cleanedToken = await _context.RefreshTokens
            .FirstOrDefaultAsync(t => t.Token == "old_expired_token");
        cleanedToken.Should().BeNull();
    }
}