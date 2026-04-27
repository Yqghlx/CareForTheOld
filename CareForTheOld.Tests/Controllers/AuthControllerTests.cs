using CareForTheOld.Common.Constants;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Auth;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// AuthController 测试
/// 覆盖：注册、登录、刷新令牌的响应格式和服务调用
/// </summary>
public class AuthControllerTests
{
    private readonly Mock<IAuthService> _mockAuthService;
    private readonly AuthController _controller;

    public AuthControllerTests()
    {
        _mockAuthService = new Mock<IAuthService>();
        _controller = new AuthController(_mockAuthService.Object);
    }

    [Fact]
    public async Task Register_应返回成功响应并包含认证数据()
    {
        // Arrange
        var request = new RegisterRequest
        {
            PhoneNumber = "13800138000",
            Password = "Test1234",
            RealName = "张大爷",
            Role = UserRole.Elder
        };

        var expectedResponse = new AuthResponse
        {
            AccessToken = "test-access-token",
            RefreshToken = "test-refresh-token",
            User = new UserResponse { Id = Guid.NewGuid(), PhoneNumber = "13800138000", RealName = "张大爷" }
        };

        _mockAuthService
            .Setup(s => s.RegisterAsync(request))
            .ReturnsAsync(expectedResponse);

        // Act
        var result = await _controller.Register(request);

        // Assert
        result.Should().NotBeNull();
        result.Success.Should().BeTrue();
        result.Data.Should().BeEquivalentTo(expectedResponse);
        result.Message.Should().Be(SuccessMessages.Auth.RegisterSuccess);
    }

    [Fact]
    public async Task Login_应返回成功响应并包含认证数据()
    {
        // Arrange
        var request = new LoginRequest { PhoneNumber = "13800138000", Password = "Test1234" };
        var expectedResponse = new AuthResponse
        {
            AccessToken = "login-token",
            RefreshToken = "refresh-token",
            User = new UserResponse { Id = Guid.NewGuid(), PhoneNumber = "13800138000" }
        };

        _mockAuthService
            .Setup(s => s.LoginAsync(request))
            .ReturnsAsync(expectedResponse);

        // Act
        var result = await _controller.Login(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.AccessToken.Should().Be("login-token");
        result.Message.Should().Be(SuccessMessages.Auth.LoginSuccess);
    }

    [Fact]
    public async Task Refresh_应返回新的认证令牌()
    {
        // Arrange
        var request = new RefreshTokenRequest { RefreshToken = "old-refresh-token" };
        var expectedResponse = new AuthResponse
        {
            AccessToken = "new-access-token",
            RefreshToken = "new-refresh-token",
            User = new UserResponse { Id = Guid.NewGuid() }
        };

        _mockAuthService
            .Setup(s => s.RefreshTokenAsync("old-refresh-token"))
            .ReturnsAsync(expectedResponse);

        // Act
        var result = await _controller.Refresh(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.AccessToken.Should().Be("new-access-token");
        result.Message.Should().Be(SuccessMessages.Auth.RefreshSuccess);
    }

    [Fact]
    public async Task Register_服务抛异常应向上传播()
    {
        // Arrange
        var request = new RegisterRequest
        {
            PhoneNumber = "13800138000",
            Password = "Test1234",
            RealName = "测试",
            Role = UserRole.Elder
        };

        _mockAuthService
            .Setup(s => s.RegisterAsync(request))
            .ThrowsAsync(new InvalidOperationException(ErrorMessages.Auth.PhoneAlreadyRegistered));

        // Act
        var act = () => _controller.Register(request);

        // Assert - 异常由中间件统一处理，控制器不捕获
        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage(ErrorMessages.Auth.PhoneAlreadyRegistered);
    }
}
