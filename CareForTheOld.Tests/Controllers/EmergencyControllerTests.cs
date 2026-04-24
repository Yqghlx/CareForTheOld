using System.Security.Claims;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Emergency;
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
/// EmergencyController 测试
/// 覆盖：老人发起呼叫、子女获取未读、子女响应、历史记录
/// </summary>
public class EmergencyControllerTests
{
    private readonly Mock<IEmergencyService> _mockService;
    private readonly EmergencyController _controller;
    private readonly Guid _elderId = Guid.NewGuid();
    private readonly Guid _childId = Guid.NewGuid();

    public EmergencyControllerTests()
    {
        _mockService = new Mock<IEmergencyService>();
        _controller = new EmergencyController(_mockService.Object);
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
    public async Task CreateCall_老人发起紧急呼叫应返回成功()
    {
        // Arrange
        SetElderUser();
        var request = new CreateEmergencyCallRequest
        {
            Latitude = 39.9042,
            Longitude = 116.4074,
            BatteryLevel = 85
        };

        var expected = new EmergencyCallResponse
        {
            Id = Guid.NewGuid(),
            ElderId = _elderId,
            Latitude = 39.9042,
            Longitude = 116.4074,
            BatteryLevel = 85,
            Status = EmergencyStatus.Pending
        };

        _mockService
            .Setup(s => s.CreateCallAsync(_elderId, 39.9042, 116.4074, 85))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.CreateCall(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Status.Should().Be(EmergencyStatus.Pending);
        result.Data.BatteryLevel.Should().Be(85);
        result.Message.Should().Be("紧急呼叫已发送，已通知家人和附近邻居");
    }

    [Fact]
    public async Task CreateCall_无位置信息也应成功()
    {
        // Arrange
        SetElderUser();
        var expected = new EmergencyCallResponse
        {
            Id = Guid.NewGuid(),
            ElderId = _elderId,
            Status = EmergencyStatus.Pending
        };

        _mockService
            .Setup(s => s.CreateCallAsync(_elderId, null, null, null))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.CreateCall(null);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Latitude.Should().BeNull();
    }

    [Fact]
    public async Task GetUnreadCalls_子女应获取未处理呼叫列表()
    {
        // Arrange
        SetChildUser();
        var calls = new List<EmergencyCallResponse>
        {
            new() { Id = Guid.NewGuid(), Status = EmergencyStatus.Pending },
            new() { Id = Guid.NewGuid(), Status = EmergencyStatus.Pending }
        };

        _mockService
            .Setup(s => s.GetUnreadCallsAsync(_childId))
            .ReturnsAsync(calls);

        // Act
        var result = await _controller.GetUnreadCalls();

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(2);
    }

    [Fact]
    public async Task RespondCall_子女标记处理应成功()
    {
        // Arrange
        SetChildUser();
        var callId = Guid.NewGuid();
        var expected = new EmergencyCallResponse
        {
            Id = callId,
            Status = EmergencyStatus.Responded,
            RespondedBy = _childId
        };

        _mockService
            .Setup(s => s.RespondCallAsync(callId, _childId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.RespondCall(callId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Status.Should().Be(EmergencyStatus.Responded);
        result.Message.Should().Be("已标记处理");
    }

    [Fact]
    public async Task GetHistory_应正确传递分页参数()
    {
        // Arrange
        SetElderUser();
        _mockService
            .Setup(s => s.GetHistoryAsync(_elderId, 10, 20))
            .ReturnsAsync([]);

        // Act
        var result = await _controller.GetHistory(10, 20);

        // Assert
        result.Success.Should().BeTrue();
        _mockService.Verify(s => s.GetHistoryAsync(_elderId, 10, 20), Times.Once);
    }

    [Fact]
    public async Task GetHistory_limit超过100应被截断()
    {
        // Arrange
        SetElderUser();
        _mockService
            .Setup(s => s.GetHistoryAsync(_elderId, 0, 100))
            .ReturnsAsync([]);

        // Act
        await _controller.GetHistory(0, 500);

        // Assert
        _mockService.Verify(s => s.GetHistoryAsync(_elderId, 0, 100), Times.Once);
    }
}
