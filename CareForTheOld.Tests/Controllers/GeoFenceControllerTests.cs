using System.Security.Claims;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.GeoFences;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// GeoFenceController 测试
/// 覆盖：围栏CRUD、家庭成员校验
/// </summary>
public class GeoFenceControllerTests
{
    private readonly Mock<IGeoFenceService> _mockFenceService;
    private readonly Mock<IFamilyService> _mockFamilyService;
    private readonly GeoFenceController _controller;
    private readonly Guid _childId = Guid.NewGuid();

    public GeoFenceControllerTests()
    {
        _mockFenceService = new Mock<IGeoFenceService>();
        _mockFamilyService = new Mock<IFamilyService>();
        _controller = new GeoFenceController(_mockFenceService.Object, _mockFamilyService.Object);
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
    public async Task CreateFence_子女创建围栏应成功()
    {
        // Arrange
        SetChildUser();
        var elderId = Guid.NewGuid();
        var request = new CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500,
            IsEnabled = true
        };

        var expected = new GeoFenceResponse
        {
            Id = Guid.NewGuid(),
            ElderId = elderId,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500,
            IsEnabled = true,
            CreatedBy = _childId
        };

        _mockFenceService
            .Setup(s => s.CreateFenceAsync(_childId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.CreateFence(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Radius.Should().Be(500);
        result.Message.Should().Be("围栏创建成功");
    }

    [Fact]
    public async Task GetElderFence_子女与老人不同家庭应返回失败()
    {
        // Arrange
        SetChildUser();
        var elderId = Guid.NewGuid();
        var childFamilyId = Guid.NewGuid();
        var elderFamilyId = Guid.NewGuid(); // 不同家庭

        _mockFamilyService
            .Setup(s => s.GetMyFamilyAsync(_childId))
            .ReturnsAsync(new FamilyResponse { Id = childFamilyId });
        _mockFamilyService
            .Setup(s => s.GetMyFamilyAsync(elderId))
            .ReturnsAsync(new FamilyResponse { Id = elderFamilyId });

        // Act
        var result = await _controller.GetElderFence(elderId);

        // Assert
        result.Success.Should().BeFalse();
        result.Message.Should().Be("无权查看该老人的围栏信息");
    }

    [Fact]
    public async Task GetElderFence_子女与老人同家庭应返回围栏()
    {
        // Arrange
        SetChildUser();
        var elderId = Guid.NewGuid();
        var familyId = Guid.NewGuid();

        _mockFamilyService
            .Setup(s => s.GetMyFamilyAsync(_childId))
            .ReturnsAsync(new FamilyResponse { Id = familyId });
        _mockFamilyService
            .Setup(s => s.GetMyFamilyAsync(elderId))
            .ReturnsAsync(new FamilyResponse { Id = familyId });

        var fence = new GeoFenceResponse
        {
            Id = Guid.NewGuid(),
            ElderId = elderId,
            Radius = 300,
            IsEnabled = true
        };

        _mockFenceService
            .Setup(s => s.GetElderFenceAsync(elderId))
            .ReturnsAsync(fence);

        // Act
        var result = await _controller.GetElderFence(elderId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Radius.Should().Be(300);
    }

    [Fact]
    public async Task UpdateFence_应传递正确的参数()
    {
        // Arrange
        SetChildUser();
        var fenceId = Guid.NewGuid();
        var request = new CreateGeoFenceRequest
        {
            ElderId = Guid.NewGuid(),
            CenterLatitude = 39.9,
            CenterLongitude = 116.4,
            Radius = 800,
            IsEnabled = true
        };

        var expected = new GeoFenceResponse
        {
            Id = fenceId,
            Radius = 800
        };

        _mockFenceService
            .Setup(s => s.UpdateFenceAsync(fenceId, _childId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.UpdateFence(fenceId, request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Radius.Should().Be(800);
        result.Message.Should().Be("围栏更新成功");
    }

    [Fact]
    public async Task DeleteFence_应传递正确的围栏ID和用户ID()
    {
        // Arrange
        SetChildUser();
        var fenceId = Guid.NewGuid();

        _mockFenceService
            .Setup(s => s.DeleteFenceAsync(fenceId, _childId))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.DeleteFence(fenceId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be("围栏删除成功");
        _mockFenceService.Verify(s => s.DeleteFenceAsync(fenceId, _childId), Times.Once);
    }
}
