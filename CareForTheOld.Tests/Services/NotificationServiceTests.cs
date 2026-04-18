using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.AspNetCore.SignalR;

using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

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
        // 使用 InMemory 数据库，GUID 命名确保测试隔离
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);

        // Mock IHubContext<NotificationHub>
        _mockHubContext = new Mock<IHubContext<NotificationHub>>();
        _mockClients = new Mock<IHubClients>();
        _mockClientProxy = new Mock<IClientProxy>();

        _mockHubContext.Setup(h => h.Clients).Returns(_mockClients.Object);
        _mockClients.Setup(c => c.Group(It.IsAny<string>())).Returns(_mockClientProxy.Object);

        _service = new NotificationService(_mockHubContext.Object, _context);
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

    [Fact]
    public async Task SendToUserAsync_ShouldPersistAndPush()
    {
        // 准备：创建目标用户
        var user = await CreateUserAsync("13500001001", "通知接收者");

        var notificationData = new
        {
            Title = "服药提醒",
            Content = "该吃降压药了"
        };

        // 执行：向用户发送通知
        await _service.SendToUserAsync(user.Id, "MedicationReminder", notificationData);

        // 验证：数据库中存在通知记录
        var record = await _context.NotificationRecords
            .FirstOrDefaultAsync(n => n.UserId == user.Id);
        record.Should().NotBeNull();
        record!.Type.Should().Be("MedicationReminder");
        record.Title.Should().Be("服药提醒");
        record.Content.Should().Be("该吃降压药了");
        record.IsRead.Should().BeFalse();

        // 验证：SignalR 推送被调用（通过 Group 方式发送）
        _mockClients.Verify(
            c => c.Group($"user_{user.Id}"),
            Times.Once);
        _mockClientProxy.Verify(
            p => p.SendCoreAsync("ReceiveNotification",
                It.Is<object[]>(args =>
                    args.Length == 2
                    && (string)args[0] == "MedicationReminder"),
                default),
            Times.Once);
    }

    [Fact]
    public async Task SendToFamilyAsync_ShouldSendToAllMembers()
    {
        // 准备
        var familyId = Guid.NewGuid();
        var notificationData = new
        {
            Title = "紧急呼叫",
            Content = "老人发起了紧急呼叫"
        };

        // 执行：向家庭组发送通知
        await _service.SendToFamilyAsync(familyId, "EmergencyCall", notificationData);

        // 验证：SignalR 向家庭组推送通知
        _mockClients.Verify(
            c => c.Group($"family_{familyId}"),
            Times.Once);
        _mockClientProxy.Verify(
            p => p.SendCoreAsync("ReceiveNotification",
                It.Is<object[]>(args =>
                    args.Length == 2
                    && (string)args[0] == "EmergencyCall"),
                default),
            Times.Once);
    }
}
