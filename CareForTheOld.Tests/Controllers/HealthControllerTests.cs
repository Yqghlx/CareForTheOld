using System.Security.Claims;
using CareForTheOld.Common.Constants;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Health;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// HealthController 测试
/// 覆盖：创建记录（老人）、查询记录、家庭成员权限校验、删除、PDF导出
/// </summary>
public class HealthControllerTests
{
    private readonly Mock<IHealthService> _mockHealthService;
    private readonly Mock<IHealthQueryService> _mockQueryService;
    private readonly Mock<IFamilyService> _mockFamilyService;
    private readonly Mock<IHealthReportService> _mockReportService;
    private readonly HealthAnomalyDetector _anomalyDetector;
    private readonly HealthController _controller;
    private readonly Guid _elderId = Guid.NewGuid();
    private readonly Guid _childId = Guid.NewGuid();

    public HealthControllerTests()
    {
        _mockHealthService = new Mock<IHealthService>();
        _mockQueryService = new Mock<IHealthQueryService>();
        _mockFamilyService = new Mock<IFamilyService>();
        _mockReportService = new Mock<IHealthReportService>();
        _anomalyDetector = new HealthAnomalyDetector(new Mock<ILogger<HealthAnomalyDetector>>().Object);

        _controller = new HealthController(
            _mockHealthService.Object,
            _mockQueryService.Object,
            _mockFamilyService.Object,
            _mockReportService.Object,
            _anomalyDetector
        );
    }

    /// <summary>
    /// 设置控制器用户上下文，模拟已认证的老人用户
    /// </summary>
    private void SetElderUser()
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, _elderId.ToString()),
            new(ClaimTypes.Role, "Elder")
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(identity) }
        };
    }

    /// <summary>
    /// 设置控制器用户上下文，模拟已认证的子女用户
    /// </summary>
    private void SetChildUser()
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, _childId.ToString()),
            new(ClaimTypes.Role, "Child")
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(identity) }
        };
    }

    [Fact]
    public async Task CreateRecord_老人创建血压记录应返回成功()
    {
        // Arrange
        SetElderUser();
        var request = new CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        };

        var expected = new HealthRecordResponse
        {
            Id = Guid.NewGuid(),
            UserId = _elderId,
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        };

        _mockHealthService
            .Setup(s => s.CreateRecordAsync(_elderId, request))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.CreateRecord(request);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.Systolic.Should().Be(120);
        result.Data.Diastolic.Should().Be(80);
        result.Message.Should().Be(SuccessMessages.Health.RecordSuccess);
        _mockHealthService.Verify(s => s.CreateRecordAsync(_elderId, request), Times.Once);
    }

    [Fact]
    public async Task GetMyRecords_应传递正确的用户ID和分页参数()
    {
        // Arrange
        SetElderUser();
        var records = new List<HealthRecordResponse>
        {
            new() { Id = Guid.NewGuid(), UserId = _elderId, Type = HealthType.BloodSugar }
        };

        _mockHealthService
            .Setup(s => s.GetUserRecordsAsync(_elderId, null, 0, 50))
            .ReturnsAsync(records);

        // Act
        var result = await _controller.GetMyRecords(null, 0, 50);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(1);
    }

    [Fact]
    public async Task GetMyRecords_limit超过100应被截断()
    {
        // Arrange
        SetElderUser();
        _mockHealthService
            .Setup(s => s.GetUserRecordsAsync(_elderId, null, 0, 100))
            .ReturnsAsync([]);

        // Act
        await _controller.GetMyRecords(null, 0, 999);

        // Assert - 验证 limit 被 Clamp 到 100
        _mockHealthService.Verify(
            s => s.GetUserRecordsAsync(_elderId, null, 0, 100), Times.Once);
    }

    [Fact]
    public async Task GetFamilyMemberRecords_子女非家庭成员应返回失败()
    {
        // Arrange
        SetChildUser();
        var familyId = Guid.NewGuid();
        var memberId = Guid.NewGuid();

        // 模拟子女不属于该家庭
        _mockFamilyService
            .Setup(s => s.GetMembersAsync(familyId))
            .ReturnsAsync([]);

        // Act
        var result = await _controller.GetFamilyMemberRecords(familyId, memberId, null, 0, 50);

        // Assert
        result.Success.Should().BeFalse();
        result.Message.Should().Be(ErrorMessages.Family.NotFamilyMember);
    }

    [Fact]
    public async Task GetFamilyMemberRecords_子女是家庭成员应返回记录()
    {
        // Arrange
        SetChildUser();
        var familyId = Guid.NewGuid();
        var memberId = Guid.NewGuid();

        // 模拟子女属于该家庭
        _mockFamilyService
            .Setup(s => s.GetMembersAsync(familyId))
            .ReturnsAsync([new FamilyMemberResponse { UserId = _childId }]);

        var expected = new List<HealthRecordResponse>
        {
            new() { Id = Guid.NewGuid(), UserId = memberId }
        };

        _mockHealthService
            .Setup(s => s.GetFamilyMemberRecordsAsync(familyId, memberId, null, 0, 50))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.GetFamilyMemberRecords(familyId, memberId, null, 0, 50);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(1);
    }

    [Fact]
    public async Task GetMyStats_应调用查询服务()
    {
        // Arrange
        SetElderUser();
        var stats = new List<HealthStatsResponse>
        {
            new() { TypeName = "血压", Average7Days = 125.5m }
        };

        _mockQueryService
            .Setup(s => s.GetUserStatsAsync(_elderId))
            .ReturnsAsync(stats);

        // Act
        var result = await _controller.GetMyStats();

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(1);
        _mockQueryService.Verify(s => s.GetUserStatsAsync(_elderId), Times.Once);
    }

    [Fact]
    public async Task DeleteRecord_应传递正确的用户ID和记录ID()
    {
        // Arrange
        SetElderUser();
        var recordId = Guid.NewGuid();

        _mockHealthService
            .Setup(s => s.DeleteRecordAsync(_elderId, recordId))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.DeleteRecord(recordId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be(SuccessMessages.Health.DeleteSuccess);
        _mockHealthService.Verify(s => s.DeleteRecordAsync(_elderId, recordId), Times.Once);
    }

    [Fact]
    public async Task ExportMyReport_应返回PDF文件()
    {
        // Arrange
        SetElderUser();
        var pdfBytes = new byte[] { 0x25, 0x50, 0x44, 0x46 }; // %PDF magic bytes

        _mockReportService
            .Setup(s => s.GeneratePdfReportAsync(_elderId, 7))
            .ReturnsAsync(pdfBytes);

        // Act
        var result = await _controller.ExportMyReport(7);

        // Assert
        result.Should().BeOfType<FileContentResult>();
        var fileResult = result as FileContentResult;
        fileResult!.ContentType.Should().Be("application/pdf");
        fileResult.FileContents.Should().Equal(pdfBytes);
        fileResult.FileDownloadName.Should().Contain("健康报告_");
    }
}
