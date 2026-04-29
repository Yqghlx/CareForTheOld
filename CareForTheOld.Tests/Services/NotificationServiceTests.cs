using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

using static CareForTheOld.Common.Constants.AppConstants.Pagination;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// NotificationService 单元测试
/// </summary>
public class NotificationServiceTests
{
    private readonly AppDbContext _context;
    private readonly NotificationService _service;
    private readonly Mock<IHubContext<NotificationHub>> _mockHubContext;
    private readonly Mock<IHubClients> _mockClients;
    private readonly Mock<IClientProxy> _mockClientProxy;

    public NotificationServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);

        _mockHubContext = new Mock<IHubContext<NotificationHub>>();
        _mockClients = new Mock<IHubClients>();
        _mockClientProxy = new Mock<IClientProxy>();

        _mockHubContext.Setup(h => h.Clients).Returns(_mockClients.Object);
        _mockClients.Setup(c => c.Group(It.IsAny<string>())).Returns(_mockClientProxy.Object);

        _service = new NotificationService(_mockHubContext.Object, _context, NullLogger<NotificationService>.Instance);
    }

    /// <summary>
    /// 创建用户并保存到数据库
    /// </summary>
    private async Task<User> CreateUserAsync(
        string phone = "13500001111",
        string name = "通知测试用户")
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = phone,
            PasswordHash = "hash",
            RealName = name,
            BirthDate = new DateOnly(1992, 4, 15),
            Role = UserRole.Child
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    /// <summary>
    /// 创建测试通知
    /// </summary>
    private async Task<NotificationRecord> CreateNotificationAsync(
        Guid userId, string type = "Test", string title = "测试通知", bool isRead = false)
    {
        var notification = new NotificationRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = type,
            Title = title,
            Content = "测试内容",
            IsRead = isRead,
            CreatedAt = DateTime.UtcNow
        };
        _context.NotificationRecords.Add(notification);
        await _context.SaveChangesAsync();
        return notification;
    }

    [Fact]
    public async Task SendToUserAsync_ShouldPersistRecordAndOutbox()
    {
        var user = await CreateUserAsync("13500001001", "通知接收者");

        var notificationData = new
        {
            Title = "服药提醒",
            Content = "该吃降压药了"
        };

        await _service.SendToUserAsync(user.Id, "MedicationReminder", notificationData);

        // 验证通知记录已持久化
        var record = await _context.NotificationRecords
            .FirstOrDefaultAsync(n => n.UserId == user.Id);
        record.Should().NotBeNull();
        record!.Type.Should().Be("MedicationReminder");
        record.Title.Should().Be("服药提醒");
        record.Content.Should().Be("该吃降压药了");
        record.IsRead.Should().BeFalse();

        // 验证 Outbox 消息已写入（SignalR 推送由后台 Job 异步处理）
        var outbox = await _context.NotificationOutboxes
            .FirstOrDefaultAsync(o => o.UserId == user.Id);
        outbox.Should().NotBeNull();
        outbox!.Type.Should().Be("MedicationReminder");
        outbox.Status.Should().Be(OutboxStatus.Pending);
        // JSON 序列化中文会被 Unicode 转义，验证包含 Title 字段即可
        outbox.Payload.Should().Contain("Title");
    }

    [Fact]
    public async Task SendToFamilyAsync_ShouldSendToAllMembers()
    {
        var familyId = Guid.NewGuid();
        var notificationData = new { Title = "紧急呼叫", Content = "老人发起了紧急呼叫" };

        await _service.SendToFamilyAsync(familyId, "EmergencyCall", notificationData);

        _mockClients.Verify(c => c.Group($"family_{familyId}"), Times.Once);
    }

    [Fact]
    public async Task GetUserNotificationsAsync_ShouldReturnUserNotifications()
    {
        var user = await CreateUserAsync();
        // 创建该用户的通知和其他用户的通知
        await CreateNotificationAsync(user.Id, "Type1", "通知1");
        await CreateNotificationAsync(user.Id, "Type2", "通知2");
        await CreateNotificationAsync(Guid.NewGuid(), "Type3", "其他用户通知");

        var result = await _service.GetUserNotificationsAsync(user.Id, limit: 10);

        result.Items.Should().HaveCount(2);
        // 验证返回的均为该用户的通知（通过标题区分）
        result.Items.Should().OnlyContain(r => r.Title == "通知1" || r.Title == "通知2");
        result.TotalCount.Should().Be(2);
    }

    [Fact]
    public async Task GetUserNotificationsAsync_ShouldRespectLimit()
    {
        var user = await CreateUserAsync();
        for (int i = 0; i < 5; i++)
        {
            await CreateNotificationAsync(user.Id, "Type", $"通知{i}");
        }

        var result = await _service.GetUserNotificationsAsync(user.Id, limit: 3);

        result.Items.Should().HaveCount(3);
        result.TotalCount.Should().Be(5);
        result.HasMore.Should().BeTrue();
    }

    [Fact]
    public async Task GetUnreadCountAsync_ShouldReturnCorrectCount()
    {
        var user = await CreateUserAsync();
        await CreateNotificationAsync(user.Id, isRead: false);
        await CreateNotificationAsync(user.Id, isRead: false);
        await CreateNotificationAsync(user.Id, isRead: true);

        var count = await _service.GetUnreadCountAsync(user.Id);

        count.Should().Be(2);
    }

    [Fact]
    public async Task MarkAsReadAsync_ShouldMarkNotificationAsRead()
    {
        var user = await CreateUserAsync();
        var notification = await CreateNotificationAsync(user.Id, isRead: false);

        var success = await _service.MarkAsReadAsync(notification.Id, user.Id);

        success.Should().BeTrue();
        var updated = await _context.NotificationRecords.FindAsync(notification.Id);
        updated!.IsRead.Should().BeTrue();
    }

    [Fact]
    public async Task MarkAsReadAsync_ShouldReturnFalseForOtherUsersNotification()
    {
        var user = await CreateUserAsync();
        var otherUser = await CreateUserAsync("13500002222", "其他用户");
        var notification = await CreateNotificationAsync(otherUser.Id, isRead: false);

        var success = await _service.MarkAsReadAsync(notification.Id, user.Id);

        success.Should().BeFalse();
    }

    [Fact]
    public async Task MarkAllAsReadAsync_ShouldMarkAllUnreadNotifications()
    {
        var user = await CreateUserAsync();
        await CreateNotificationAsync(user.Id, isRead: false);
        await CreateNotificationAsync(user.Id, isRead: false);
        await CreateNotificationAsync(user.Id, isRead: true);

        await _service.MarkAllAsReadAsync(user.Id);

        var unreadCount = await _context.NotificationRecords
            .CountAsync(n => n.UserId == user.Id && !n.IsRead);
        unreadCount.Should().Be(0);
    }
}
