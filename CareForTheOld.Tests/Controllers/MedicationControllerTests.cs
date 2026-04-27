using System.Security.Claims;
using CareForTheOld.Common.Constants;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Medication;
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
/// MedicationController 测试
/// 覆盖：计划CRUD（子女）、日志记录（老人）、今日待服（老人）
/// </summary>
public class MedicationControllerTests
{
    private readonly Mock<IMedicationService> _mockService;
    private readonly MedicationController _controller;
    private readonly Guid _elderId = Guid.NewGuid();
    private readonly Guid _childId = Guid.NewGuid();

    public MedicationControllerTests()
    {
        _mockService = new Mock<IMedicationService>();
        _controller = new MedicationController(_mockService.Object);
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
    public async Task CreatePlan_子女创建计划应返回成功()
    {
        // Arrange
        SetChildUser();
        var request = new CreateMedicationPlanRequest
        {
            ElderId = _elderId,
            MedicineName = "降压药",
            Dosage = "1片",
            Frequency = Frequency.TwiceDaily
        };

        var expected = new MedicationPlanResponse
        {
            Id = Guid.NewGuid(),
            ElderId = _elderId,
            MedicineName = "降压药",
            Frequency = Frequency.TwiceDaily
        };

        _mockService
            .Setup(s => s.CreatePlanAsync(_childId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.CreatePlan(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.MedicineName.Should().Be("降压药");
        result.Message.Should().Be(SuccessMessages.Medication.CreateSuccess);
    }

    [Fact]
    public async Task GetMyPlans_老人获取自己的计划()
    {
        // Arrange
        SetElderUser();
        var plans = new List<MedicationPlanResponse>
        {
            new() { Id = Guid.NewGuid(), ElderId = _elderId, MedicineName = "降压药" }
        };

        _mockService
            .Setup(s => s.GetPlansByElderAsync(_elderId))
            .ReturnsAsync(plans);

        // Act
        var result = await _controller.GetMyPlans();

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(1);
        _mockService.Verify(s => s.GetPlansByElderAsync(_elderId), Times.Once);
    }

    [Fact]
    public async Task GetPlansByElder_子女查看老人计划应传递双方ID()
    {
        // Arrange
        SetChildUser();
        var plans = new List<MedicationPlanResponse>();

        _mockService
            .Setup(s => s.GetPlansByElderAsync(_elderId, _childId))
            .ReturnsAsync(plans);

        // Act
        var result = await _controller.GetPlansByElder(_elderId);

        // Assert
        result.Success.Should().BeTrue();
        _mockService.Verify(s => s.GetPlansByElderAsync(_elderId, _childId), Times.Once);
    }

    [Fact]
    public async Task RecordLog_老人记录服药应返回成功()
    {
        // Arrange
        SetElderUser();
        var request = new RecordMedicationLogRequest
        {
            PlanId = Guid.NewGuid(),
            Status = MedicationStatus.Taken,
            ScheduledAt = DateTime.UtcNow
        };

        var expected = new MedicationLogResponse
        {
            Id = Guid.NewGuid(),
            Status = MedicationStatus.Taken
        };

        _mockService
            .Setup(s => s.RecordLogAsync(_elderId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.RecordLog(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Status.Should().Be(MedicationStatus.Taken);
        result.Message.Should().Be(SuccessMessages.Medication.LogSuccess);
    }

    [Fact]
    public async Task GetTodayPending_老人获取今日待服列表()
    {
        // Arrange
        SetElderUser();
        var pending = new List<MedicationLogResponse>
        {
            new() { Id = Guid.NewGuid(), Status = MedicationStatus.Missed }
        };

        _mockService
            .Setup(s => s.GetTodayPendingAsync(_elderId))
            .ReturnsAsync(pending);

        // Act
        var result = await _controller.GetTodayPending();

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(1);
    }

    [Fact]
    public async Task DeletePlan_子女删除计划应传递正确参数()
    {
        // Arrange
        SetChildUser();
        var planId = Guid.NewGuid();

        _mockService
            .Setup(s => s.DeletePlanAsync(planId, _childId))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.DeletePlan(planId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be(SuccessMessages.Medication.DeleteSuccess);
        _mockService.Verify(s => s.DeletePlanAsync(planId, _childId), Times.Once);
    }
}
