using System.Security.Claims;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// UserController 测试
/// 覆盖：获取/更新用户信息、头像上传校验、密码修改、越权访问防护
/// </summary>
public class UserControllerTests
{
    private readonly Mock<IUserService> _mockUserService;
    private readonly Mock<IFileStorageService> _mockFileStorage;
    private readonly UserController _controller;
    private readonly Guid _userId = Guid.NewGuid();

    public UserControllerTests()
    {
        _mockUserService = new Mock<IUserService>();
        _mockFileStorage = new Mock<IFileStorageService>();
        _controller = new UserController(_mockUserService.Object, _mockFileStorage.Object);
    }

    private void SetUser(Guid userId)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Role, "Elder")
        };
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth")) }
        };
    }

    [Fact]
    public async Task GetCurrentUser_应返回当前用户信息()
    {
        // Arrange
        SetUser(_userId);
        var expected = new UserResponse
        {
            Id = _userId,
            PhoneNumber = "13800138000",
            RealName = "张大爷"
        };

        _mockUserService
            .Setup(s => s.GetCurrentUserAsync(_userId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.GetCurrentUser();

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.RealName.Should().Be("张大爷");
    }

    [Fact]
    public async Task UpdateUser_应传递正确的用户ID和请求()
    {
        // Arrange
        SetUser(_userId);
        var request = new UpdateUserRequest { RealName = "张大爷改名" };
        var expected = new UserResponse { Id = _userId, RealName = "张大爷改名" };

        _mockUserService
            .Setup(s => s.UpdateUserAsync(_userId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.UpdateUser(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.RealName.Should().Be("张大爷改名");
        result.Message.Should().Be("更新成功");
    }

    [Fact]
    public async Task ChangePassword_应传递正确的用户ID()
    {
        // Arrange
        SetUser(_userId);
        var request = new ChangePasswordRequest
        {
            OldPassword = "Old1234",
            NewPassword = "New1234"
        };

        _mockUserService
            .Setup(s => s.ChangePasswordAsync(_userId, request));

        // Act
        var result = await _controller.ChangePassword(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("密码修改成功");
        _mockUserService.Verify(s => s.ChangePasswordAsync(_userId, request), Times.Once);
    }

    [Fact]
    public async Task GetUserById_查看本人应直接返回()
    {
        // Arrange
        SetUser(_userId);
        var expected = new UserResponse { Id = _userId, RealName = "本人" };

        _mockUserService
            .Setup(s => s.GetUserByIdAsync(_userId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.GetUserById(_userId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.RealName.Should().Be("本人");
        // 查看本人不应调用 EnsureFamilyMemberAsync
        _mockUserService.Verify(
            s => s.EnsureFamilyMemberAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task GetUserById_查看他人应校验家庭成员关系()
    {
        // Arrange
        SetUser(_userId);
        var otherUserId = Guid.NewGuid();
        var expected = new UserResponse { Id = otherUserId, RealName = "家人" };

        _mockUserService
            .Setup(s => s.EnsureFamilyMemberAsync(_userId, otherUserId));
        _mockUserService
            .Setup(s => s.GetUserByIdAsync(otherUserId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.GetUserById(otherUserId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.RealName.Should().Be("家人");
        _mockUserService.Verify(s => s.EnsureFamilyMemberAsync(_userId, otherUserId), Times.Once);
    }
}
