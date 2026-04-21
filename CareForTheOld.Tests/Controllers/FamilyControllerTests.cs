using System.Security.Claims;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// FamilyController 测试
/// 覆盖：创建家庭、加入家庭、成员管理、权限校验
/// </summary>
public class FamilyControllerTests
{
    private readonly Mock<IFamilyService> _mockService;
    private readonly FamilyController _controller;
    private readonly Guid _userId = Guid.NewGuid();

    public FamilyControllerTests()
    {
        _mockService = new Mock<IFamilyService>();
        _controller = new FamilyController(_mockService.Object);
    }

    private void SetUser(Guid userId)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Role, "Child")
        };
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth")) }
        };
    }

    [Fact]
    public async Task GetMyFamily_应返回当前用户的家庭信息()
    {
        // Arrange
        SetUser(_userId);
        var family = new FamilyResponse { Id = Guid.NewGuid(), FamilyName = "张家" };

        _mockService
            .Setup(s => s.GetMyFamilyAsync(_userId))
            .ReturnsAsync(family);

        // Act
        var result = await _controller.GetMyFamily();

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.FamilyName.Should().Be("张家");
    }

    [Fact]
    public async Task Create_应创建家庭并返回成功()
    {
        // Arrange
        SetUser(_userId);
        var request = new CreateFamilyRequest { FamilyName = "李家" };
        var expected = new FamilyResponse { Id = Guid.NewGuid(), FamilyName = "李家" };

        _mockService
            .Setup(s => s.CreateFamilyAsync(_userId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.Create(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.FamilyName.Should().Be("李家");
        result.Message.Should().Be("创建成功");
    }

    [Fact]
    public async Task JoinFamily_通过邀请码加入应成功()
    {
        // Arrange
        SetUser(_userId);
        var request = new JoinFamilyRequest { InviteCode = "123456" };
        var expected = new FamilyResponse { Id = Guid.NewGuid(), FamilyName = "王家" };

        _mockService
            .Setup(s => s.JoinFamilyByCodeAsync(_userId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.JoinFamily(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("加入成功");
        _mockService.Verify(s => s.JoinFamilyByCodeAsync(_userId, request), Times.Once);
    }

    [Fact]
    public async Task GetMembers_非家庭成员应返回失败()
    {
        // Arrange
        SetUser(_userId);
        var familyId = Guid.NewGuid();

        // 模拟用户不属于该家庭
        _mockService
            .Setup(s => s.GetMembersAsync(familyId))
            .ReturnsAsync([]);

        // Act
        var result = await _controller.GetMembers(familyId);

        // Assert
        result.Success.Should().BeFalse();
        result.Message.Should().Be("您不是该家庭成员");
    }

    [Fact]
    public async Task GetMembers_家庭成员应返回成员列表()
    {
        // Arrange
        SetUser(_userId);
        var familyId = Guid.NewGuid();

        _mockService
            .Setup(s => s.GetMembersAsync(familyId))
            .ReturnsAsync([new FamilyMemberResponse { UserId = _userId }]);

        // Act
        var result = await _controller.GetMembers(familyId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(1);
    }

    [Fact]
    public async Task RemoveMember_应传递正确的操作者和目标用户ID()
    {
        // Arrange
        SetUser(_userId);
        var familyId = Guid.NewGuid();
        var targetUserId = Guid.NewGuid();

        _mockService
            .Setup(s => s.RemoveMemberAsync(familyId, targetUserId, _userId))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.RemoveMember(familyId, targetUserId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("移除成功");
        _mockService.Verify(
            s => s.RemoveMemberAsync(familyId, targetUserId, _userId), Times.Once);
    }

    [Fact]
    public async Task RefreshInviteCode_应返回刷新后的家庭信息()
    {
        // Arrange
        SetUser(_userId);
        var familyId = Guid.NewGuid();
        var expected = new FamilyResponse { Id = familyId, InviteCode = "654321" };

        _mockService
            .Setup(s => s.RefreshInviteCodeAsync(familyId, _userId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.RefreshInviteCode(familyId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.InviteCode.Should().Be("654321");
        result.Message.Should().Be("邀请码已刷新");
    }
}
