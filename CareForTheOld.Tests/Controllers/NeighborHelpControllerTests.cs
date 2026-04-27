using System.Security.Claims;
using CareForTheOld.Common.Constants;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
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
/// NeighborHelpController 测试
/// </summary>
public class NeighborHelpControllerTests
{
    private readonly Mock<INeighborHelpService> _mockService;
    private readonly NeighborHelpController _controller;
    private readonly Guid _userId = Guid.NewGuid();

    public NeighborHelpControllerTests()
    {
        _mockService = new Mock<INeighborHelpService>();
        _controller = new NeighborHelpController(_mockService.Object);
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
    public async Task GetPending_应返回待响应列表()
    {
        // Arrange
        SetUser(_userId);
        var requests = new List<NeighborHelpRequestResponse>
        {
            new()
            {
                Id = Guid.NewGuid(),
                RequesterName = "老人",
                Status = HelpRequestStatus.Pending,
            },
        };
        _mockService.Setup(s => s.GetPendingRequestsAsync(_userId))
            .ReturnsAsync(requests);

        // Act
        var result = await _controller.GetPending();

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(1);
    }

    [Fact]
    public async Task GetHistory_应返回历史记录()
    {
        // Arrange
        SetUser(_userId);
        var history = new List<NeighborHelpRequestResponse>
        {
            new()
            {
                Id = Guid.NewGuid(),
                RequesterName = "老人1",
                Status = HelpRequestStatus.Accepted,
            },
            new()
            {
                Id = Guid.NewGuid(),
                RequesterName = "老人2",
                Status = HelpRequestStatus.Expired,
            },
        };
        _mockService.Setup(s => s.GetHistoryAsync(_userId, 0, 20))
            .ReturnsAsync(history);

        // Act
        var result = await _controller.GetHistory();

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(2);
    }

    [Fact]
    public async Task Accept_应接受求助()
    {
        // Arrange
        SetUser(_userId);
        var requestId = Guid.NewGuid();
        var expected = new NeighborHelpRequestResponse
        {
            Id = requestId,
            Status = HelpRequestStatus.Accepted,
            ResponderId = _userId,
        };
        _mockService.Setup(s => s.AcceptHelpRequestAsync(requestId, _userId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.Accept(requestId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be(SuccessMessages.NeighborHelp.AcceptSuccess);
        result.Data!.Status.Should().Be(HelpRequestStatus.Accepted);
    }

    [Fact]
    public async Task Cancel_应取消求助()
    {
        // Arrange
        SetUser(_userId);
        var requestId = Guid.NewGuid();

        // Act
        var result = await _controller.Cancel(requestId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be(SuccessMessages.NeighborHelp.CancelSuccess);
        _mockService.Verify(s => s.CancelHelpRequestAsync(requestId, _userId), Times.Once);
    }

    [Fact]
    public async Task Rate_应提交评价()
    {
        // Arrange
        SetUser(_userId);
        var requestId = Guid.NewGuid();
        var rateRequest = new RateHelpRequest { Rating = 5, Comment = "非常好" };
        var expected = new NeighborHelpRatingResponse
        {
            Id = Guid.NewGuid(),
            HelpRequestId = requestId,
            Rating = 5,
            Comment = "非常好",
        };
        _mockService.Setup(s => s.RateHelpRequestAsync(requestId, _userId, rateRequest))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.Rate(requestId, rateRequest);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be(SuccessMessages.NeighborHelp.RateSuccess);
        result.Data!.Rating.Should().Be(5);
    }

    [Fact]
    public async Task GetRequest_应返回请求详情()
    {
        // Arrange
        SetUser(_userId);
        var requestId = Guid.NewGuid();
        var expected = new NeighborHelpRequestResponse
        {
            Id = requestId,
            RequesterName = "老人",
            Status = HelpRequestStatus.Pending,
        };
        _mockService.Setup(s => s.GetRequestAsync(requestId))
            .ReturnsAsync(expected);

        // Act
        var result = await _controller.GetRequest(requestId);

        // Assert
        result.Success.Should().BeTrue();
        result.Data!.RequesterName.Should().Be("老人");
    }
}
