using System.Security.Claims;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// FamilyController 测试
/// 覆盖：创建家庭、加入家庭、成员管理、审批流程、权限校验
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
    public async Task JoinFamily_通过邀请码申请应返回申请结果()
    {
        // Arrange
        SetUser(_userId);
        var request = new JoinFamilyRequest { InviteCode = "123456", Relation = "爸爸" };
        var expected = new JoinFamilyResponse
        {
            Message = "申请已提交，等待子女审批",
            FamilyName = "王家",
            Status = FamilyMemberStatus.Pending
        };

        _mockService
            .Setup(s => s.JoinFamilyByCodeAsync(_userId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.JoinFamily(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("申请已提交");
        result.Data!.Status.Should().Be(FamilyMemberStatus.Pending);
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

    [Fact]
    public async Task GetPendingMembers_应返回待审批成员列表()
    {
        // Arrange
        SetUser(_userId);
        var familyId = Guid.NewGuid();
        var pendingMembers = new List<FamilyMemberResponse>
        {
            new() { UserId = Guid.NewGuid(), RealName = "待审批老人", Status = FamilyMemberStatus.Pending }
        };

        _mockService
            .Setup(s => s.GetPendingMembersAsync(familyId, _userId))
            .ReturnsAsync(pendingMembers);

        // Act
        var result = await _controller.GetPendingMembers(familyId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(1);
    }

    [Fact]
    public async Task ApproveMember_应调用审批通过服务()
    {
        // Arrange
        SetUser(_userId);
        var familyId = Guid.NewGuid();
        var memberId = Guid.NewGuid();

        _mockService
            .Setup(s => s.ApproveMemberAsync(familyId, memberId, _userId))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.ApproveMember(familyId, memberId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("审批通过");
        _mockService.Verify(
            s => s.ApproveMemberAsync(familyId, memberId, _userId), Times.Once);
    }

    [Fact]
    public async Task RejectMember_应调用拒绝服务()
    {
        // Arrange
        SetUser(_userId);
        var familyId = Guid.NewGuid();
        var memberId = Guid.NewGuid();

        _mockService
            .Setup(s => s.RejectMemberAsync(familyId, memberId, _userId))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.RejectMember(familyId, memberId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("已拒绝");
        _mockService.Verify(
            s => s.RejectMemberAsync(familyId, memberId, _userId), Times.Once);
    }
}
