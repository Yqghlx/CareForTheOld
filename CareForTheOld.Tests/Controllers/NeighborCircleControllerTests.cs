using System.Security.Claims;
using CareForTheOld.Common.Constants;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// NeighborCircleController 测试
/// </summary>
public class NeighborCircleControllerTests
{
    private readonly Mock<INeighborCircleService> _mockService;
    private readonly NeighborCircleController _controller;
    private readonly Guid _userId = Guid.NewGuid();

    public NeighborCircleControllerTests()
    {
        _mockService = new Mock<INeighborCircleService>();
        _controller = new NeighborCircleController(_mockService.Object);
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
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth"))
            }
        };
    }

    [Fact]
    public async Task GetMyCircle_应返回用户加入的圈子()
    {
        // Arrange
        SetUser(_userId);
        var circle = new NeighborCircleResponse
        {
            Id = Guid.NewGuid(),
            CircleName = "测试圈子",
            CreatorId = _userId,
        };
        _mockService.Setup(s => s.GetMyCircleAsync(_userId)).ReturnsAsync(circle);

        // Act
        var result = await _controller.GetMyCircle();

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.CircleName.Should().Be("测试圈子");
    }

    [Fact]
    public async Task GetMyCircle_未加入圈子应返回null()
    {
        // Arrange
        SetUser(_userId);
        _mockService.Setup(s => s.GetMyCircleAsync(_userId))
            .ReturnsAsync((NeighborCircleResponse?)null);

        // Act
        var result = await _controller.GetMyCircle();

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().BeNull();
    }

    [Fact]
    public async Task Create_应创建圈子并返回成功()
    {
        // Arrange
        SetUser(_userId);
        var request = new CreateNeighborCircleRequest
        {
            CircleName = "新圈子",
            CenterLatitude = 39.9,
            CenterLongitude = 116.4,
        };
        var expected = new NeighborCircleResponse
        {
            Id = Guid.NewGuid(),
            CircleName = "新圈子",
            CreatorId = _userId,
        };
        _mockService.Setup(s => s.CreateCircleAsync(_userId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.Create(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.CircleName.Should().Be("新圈子");
        result.Message.Should().Be("创建成功");
    }

    [Fact]
    public async Task GetCircle_非成员应抛出权限异常()
    {
        // Arrange
        SetUser(_userId);
        var circleId = Guid.NewGuid();
        _mockService.Setup(s => s.EnsureCircleMemberAsync(circleId, _userId))
            .ThrowsAsync(new UnauthorizedAccessException(ErrorMessages.NeighborCircle.NotCircleMember));

        // Act & Assert
        var act = async () => await _controller.GetCircle(circleId);
        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage(ErrorMessages.NeighborCircle.NotCircleMember);
    }

    [Fact]
    public async Task Join_应通过邀请码加入()
    {
        // Arrange
        SetUser(_userId);
        var request = new JoinNeighborCircleRequest { InviteCode = "888888" };
        var expected = new NeighborCircleResponse
        {
            Id = Guid.NewGuid(),
            CircleName = "加入的圈子",
        };
        _mockService.Setup(s => s.JoinCircleByCodeAsync(_userId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.Join(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("加入成功");
        _mockService.Verify(s => s.JoinCircleByCodeAsync(_userId, request), Times.Once);
    }

    [Fact]
    public async Task Leave_应退出圈子()
    {
        // Arrange
        SetUser(_userId);
        var circleId = Guid.NewGuid();

        // Act
        var result = await _controller.Leave(circleId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("已退出邻里圈");
        _mockService.Verify(s => s.LeaveCircleAsync(circleId, _userId), Times.Once);
    }

    [Fact]
    public async Task RefreshInviteCode_应刷新邀请码()
    {
        // Arrange
        SetUser(_userId);
        var circleId = Guid.NewGuid();
        var expected = new NeighborCircleResponse
        {
            Id = circleId,
            InviteCode = "999999",
        };
        _mockService.Setup(s => s.RefreshInviteCodeAsync(circleId, _userId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.RefreshInviteCode(circleId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.InviteCode.Should().Be("999999");
        result.Message.Should().Be("邀请码已刷新");
    }

    [Fact]
    public async Task GetMembers_成员应返回列表()
    {
        // Arrange
        SetUser(_userId);
        var circleId = Guid.NewGuid();
        var members = new List<NeighborMemberResponse>
        {
            new() { UserId = _userId, RealName = "我" },
            new() { UserId = Guid.NewGuid(), RealName = "邻居" },
        };
        _mockService.Setup(s => s.GetMembersAsync(circleId))
            .ReturnsAsync(members);

        // Act
        var result = await _controller.GetMembers(circleId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(2);
    }

    [Fact]
    public async Task SearchNearby_应返回附近圈子列表()
    {
        // Arrange
        var circles = new List<NeighborCircleResponse>
        {
            new() { Id = Guid.NewGuid(), CircleName = "附近1", DistanceMeters = 100 },
            new() { Id = Guid.NewGuid(), CircleName = "附近2", DistanceMeters = 300 },
        };
        _mockService.Setup(s => s.SearchNearbyCirclesAsync(39.9, 116.4, 2000))
            .ReturnsAsync(circles);

        // Act
        var result = await _controller.SearchNearby(39.9, 116.4, 2000);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(2);
    }
}
