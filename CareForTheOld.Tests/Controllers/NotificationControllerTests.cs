using System.Security.Claims;
using CareForTheOld.Common.Constants;
using CareForTheOld.Controllers;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Controllers;

/// <summary>
/// NotificationController 测试
/// 覆盖：通知列表、未读数量、标记已读、全部已读
/// </summary>
public class NotificationControllerTests
{
    private readonly Mock<INotificationService> _mockService;
    private readonly NotificationController _controller;
    private readonly Guid _userId = Guid.NewGuid();

    public NotificationControllerTests()
    {
        _mockService = new Mock<INotificationService>();
        _controller = new NotificationController(_mockService.Object);
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
    public async Task GetMyNotifications_应返回通知列表()
    {
        // Arrange
        SetUser(_userId);
        var notifications = new List<NotificationResponse>
        {
            new() { Id = Guid.NewGuid(), Title = "紧急呼叫", IsRead = false },
            new() { Id = Guid.NewGuid(), Title = "用药提醒", IsRead = true }
        };

        _mockService
            .Setup(s => s.GetUserNotificationsAsync(_userId, 50))
            .ReturnsAsync(notifications);

        // Act
        var result = await _controller.GetMyNotifications(50);

        // Assert
        result.Success.Should().BeTrue();
        result.Data.Should().HaveCount(2);
    }

    [Fact]
    public async Task GetUnreadCount_应返回未读数量()
    {
        // Arrange
        SetUser(_userId);
        _mockService
            .Setup(s => s.GetUnreadCountAsync(_userId))
            .ReturnsAsync(5);

        // Act
        var result = await _controller.GetUnreadCount();

        // Assert
        result.Success.Should().BeTrue();
    }

    [Fact]
    public async Task MarkAsRead_通知存在应返回成功()
    {
        // Arrange
        SetUser(_userId);
        var notificationId = Guid.NewGuid();

        _mockService
            .Setup(s => s.MarkAsReadAsync(notificationId, _userId))
            .ReturnsAsync(true);

        // Act
        var result = await _controller.MarkAsRead(notificationId);

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be(SuccessMessages.Notification.MarkedRead);
    }

    [Fact]
    public async Task MarkAsRead_通知不存在应提示不存在()
    {
        // Arrange
        SetUser(_userId);
        var notificationId = Guid.NewGuid();

        _mockService
            .Setup(s => s.MarkAsReadAsync(notificationId, _userId))
            .ReturnsAsync(false);

        // Act
        var result = await _controller.MarkAsRead(notificationId);

        // Assert
        result.Message.Should().Be(SuccessMessages.Notification.NotFound);
    }

    [Fact]
    public async Task MarkAllAsRead_应调用服务方法()
    {
        // Arrange
        SetUser(_userId);
        _mockService
            .Setup(s => s.MarkAllAsReadAsync(_userId))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.MarkAllAsRead();

        // Assert
        result.Success.Should().BeTrue();
        result.Message.Should().Be(SuccessMessages.Notification.AllMarkedRead);
        _mockService.Verify(s => s.MarkAllAsReadAsync(_userId), Times.Once);
    }
}
