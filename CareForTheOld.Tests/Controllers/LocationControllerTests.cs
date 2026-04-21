using System.Security.Claims;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Location;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// LocationController 测试
/// 覆盖：位置上报、历史查询、家庭成员权限校验
/// </summary>
public class LocationControllerTests
{
    private readonly Mock<ILocationService> _mockLocationService;
    private readonly Mock<IFamilyService> _mockFamilyService;
    private readonly LocationController _controller;
    private readonly Guid _elderId = Guid.NewGuid();
    private readonly Guid _childId = Guid.NewGuid();

    public LocationControllerTests()
    {
        _mockLocationService = new Mock<ILocationService>();
        _mockFamilyService = new Mock<IFamilyService>();
        _controller = new LocationController(_mockLocationService.Object, _mockFamilyService.Object);
    }

    private void SetElderUser()
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, _elderId.ToString()),
            new(ClaimTypes.Role, "Elder")
        };
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth")) }
        };
    }

    private void SetChildUser()
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, _childId.ToString()),
            new(ClaimTypes.Role, "Child")
        };
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity(claims, "TestAuth")) }
        };
    }

    [Fact]
    public async Task ReportLocation_老人上报位置应成功()
    {
        // Arrange
        SetElderUser();
        var request = new ReportLocationRequest
        {
            Latitude = 39.9042,
            Longitude = 116.4074,
            Accuracy = 10.0
        };

        var expected = new LocationRecordResponse
        {
            Id = Guid.NewGuid(),
            UserId = _elderId,
            Latitude = 39.9042,
            Longitude = 116.4074
        };

        _mockLocationService
            .Setup(s => s.ReportLocationAsync(_elderId, 39.9042, 116.4074, 10.0))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.ReportLocation(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Latitude.Should().Be(39.9042);
        result.Message.Should().Be("位置上报成功");
    }

    [Fact]
    public async Task GetMyLatestLocation_应返回最新位置()
    {
        // Arrange
        SetElderUser();
        var expected = new LocationRecordResponse
        {
            Id = Guid.NewGuid(),
            UserId = _elderId,
            Latitude = 39.9,
            Longitude = 116.4
        };

        _mockLocationService
            .Setup(s => s.GetLatestLocationAsync(_elderId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.GetMyLatestLocation();

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Latitude.Should().Be(39.9);
    }

    [Fact]
    public async Task GetMyHistory_应传递正确的分页参数()
    {
        // Arrange
        SetElderUser();
        _mockLocationService
            .Setup(s => s.GetLocationHistoryAsync(_elderId, 0, 50))
            .ReturnsAsync([]);

        // Act
        await _controller.GetMyHistory(0, 50);

        // Assert
        _mockLocationService.Verify(s => s.GetLocationHistoryAsync(_elderId, 0, 50), Times.Once);
    }

    [Fact]
    public async Task GetFamilyMemberLatestLocation_非家庭成员应返回失败()
    {
        // Arrange
        SetChildUser();
        var familyId = Guid.NewGuid();
        var memberId = Guid.NewGuid();

        _mockFamilyService
            .Setup(s => s.GetMembersAsync(familyId))
            .ReturnsAsync([]);

        // Act
        var result = await _controller.GetFamilyMemberLatestLocation(familyId, memberId);

        // Assert
        result.Success.Should().BeFalse();
        result.Message.Should().Be("您不是该家庭成员");
    }

    [Fact]
    public async Task GetFamilyMemberLatestLocation_家庭成员应返回老人位置()
    {
        // Arrange
        SetChildUser();
        var familyId = Guid.NewGuid();
        var elderId = Guid.NewGuid();

        _mockFamilyService
            .Setup(s => s.GetMembersAsync(familyId))
            .ReturnsAsync([new FamilyMemberResponse { UserId = _childId }]);

        var expected = new LocationRecordResponse
        {
            Id = Guid.NewGuid(),
            UserId = elderId,
            Latitude = 31.23,
            Longitude = 121.47
        };

        _mockLocationService
            .Setup(s => s.GetFamilyMemberLatestLocationAsync(familyId, elderId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.GetFamilyMemberLatestLocation(familyId, elderId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Latitude.Should().Be(31.23);
    }
}
