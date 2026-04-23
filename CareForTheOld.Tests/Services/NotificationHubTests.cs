using CareForTheOld.Services.Hubs;
using FluentAssertions;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using Moq;
using System.Collections.Concurrent;
using System.Security.Claims;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// NotificationHub 单元测试
/// 覆盖：连接管理、心跳检测、家庭组管理
/// </summary>
public class NotificationHubTests
{
    private readonly Mock<ILogger<NotificationHub>> _mockLogger;
    private readonly NotificationHub _hub;

    public NotificationHubTests()
    {
        _mockLogger = new Mock<ILogger<NotificationHub>>();
        _hub = new NotificationHub(_mockLogger.Object);
        // 每个测试开始前清理静态数据，确保测试隔离
        ClearStaticData();
    }

    /// <summary>
    /// 创建模拟的 HubCallerContext
    /// </summary>
    private Mock<HubCallerContext> CreateMockContext(string? userId, string connectionId)
    {
        var mockContext = new Mock<HubCallerContext>();
        mockContext.SetupGet(c => c.UserIdentifier).Returns(userId);
        mockContext.SetupGet(c => c.ConnectionId).Returns(connectionId);

        if (userId != null)
        {
            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, userId)
            };
            mockContext.SetupGet(c => c.User).Returns(new ClaimsPrincipal(new ClaimsIdentity(claims)));
        }
        else
        {
            mockContext.SetupGet(c => c.User).Returns(new ClaimsPrincipal());
        }

        return mockContext;
    }

    /// <summary>
    /// 创建模拟的 IGroupManager
    /// </summary>
    private Mock<IGroupManager> CreateMockGroups()
    {
        var mockGroups = new Mock<IGroupManager>();
        mockGroups.Setup(g => g.AddToGroupAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        mockGroups.Setup(g => g.RemoveFromGroupAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        return mockGroups;
    }

    /// <summary>
    /// 设置 Hub 的上下文
    /// </summary>
    private void SetupHubContext(Mock<HubCallerContext> mockContext, Mock<IGroupManager> mockGroups)
    {
        _hub.Context = mockContext.Object;
        _hub.Groups = mockGroups.Object;
    }

    [Fact]
    public async Task OnConnectedAsync_认证用户应加入个人组()
    {
        // Arrange
        var userId = Guid.NewGuid().ToString();
        var connectionId = "conn_123";
        var mockContext = CreateMockContext(userId, connectionId);
        var mockGroups = CreateMockGroups();
        SetupHubContext(mockContext, mockGroups);

        // Act
        await _hub.OnConnectedAsync();

        // Assert
        mockGroups.Verify(g => g.AddToGroupAsync(connectionId, $"user_{userId}", It.IsAny<CancellationToken>()), Times.Once);
        NotificationHub.OnlineUserCount.Should().Be(1);
        NotificationHub.LastHeartbeats.ContainsKey(userId).Should().BeTrue();
    }

    [Fact]
    public async Task OnConnectedAsync_未认证用户应拒绝连接()
    {
        // Arrange
        var mockContext = CreateMockContext(null, "conn_unauth");
        mockContext.Setup(c => c.Abort()).Verifiable();
        var mockGroups = CreateMockGroups();
        SetupHubContext(mockContext, mockGroups);

        // Act
        await _hub.OnConnectedAsync();

        // Assert
        mockContext.Verify(c => c.Abort(), Times.Once);
        mockGroups.Verify(g => g.AddToGroupAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task OnDisconnectedAsync_最后一个连接应清理在线记录()
    {
        // Arrange
        var userId = Guid.NewGuid().ToString();
        var connectionId = "conn_single";

        // 先连接
        var mockContext1 = CreateMockContext(userId, connectionId);
        var mockGroups1 = CreateMockGroups();
        SetupHubContext(mockContext1, mockGroups1);
        await _hub.OnConnectedAsync();

        // 再断开
        var mockContext2 = CreateMockContext(userId, connectionId);
        var mockGroups2 = CreateMockGroups();
        SetupHubContext(mockContext2, mockGroups2);

        // Act
        await _hub.OnDisconnectedAsync(null);

        // Assert
        mockGroups2.Verify(g => g.RemoveFromGroupAsync(connectionId, $"user_{userId}", It.IsAny<CancellationToken>()), Times.Once);
        NotificationHub.OnlineUserCount.Should().Be(0);
        NotificationHub.LastHeartbeats.ContainsKey(userId).Should().BeFalse();
    }

    [Fact]
    public async Task OnDisconnectedAsync_多连接时仅移除当前连接()
    {
        // Arrange
        var userId = Guid.NewGuid().ToString();

        // 模拟两个连接
        var mockGroups = CreateMockGroups();

        // 第一个连接
        var mockContext1 = CreateMockContext(userId, "conn_1");
        SetupHubContext(mockContext1, mockGroups);
        await _hub.OnConnectedAsync();

        // 第二个连接（需要重置 Hub 实例以模拟新连接）
        var hub2 = new NotificationHub(_mockLogger.Object);
        var mockContext2 = CreateMockContext(userId, "conn_2");
        hub2.Context = mockContext2.Object;
        hub2.Groups = mockGroups.Object;
        await hub2.OnConnectedAsync();

        // 断开第一个连接
        var mockContextDisconnect = CreateMockContext(userId, "conn_1");
        hub2.Context = mockContextDisconnect.Object;
        hub2.Groups = mockGroups.Object;

        // Act
        await hub2.OnDisconnectedAsync(null);

        // Assert
        NotificationHub.OnlineUserCount.Should().Be(1);
        NotificationHub.TotalConnectionCount.Should().Be(1);
        NotificationHub.LastHeartbeats.ContainsKey(userId).Should().BeTrue();
    }

    [Fact]
    public async Task Heartbeat_认证用户应更新最后心跳时间()
    {
        // Arrange
        var userId = Guid.NewGuid().ToString();
        var mockContext = CreateMockContext(userId, "conn_heartbeat");
        var mockGroups = CreateMockGroups();
        SetupHubContext(mockContext, mockGroups);

        // 先连接以初始化心跳
        await _hub.OnConnectedAsync();
        var initialHeartbeat = NotificationHub.LastHeartbeats[userId];

        // 等待一小段时间
        await Task.Delay(100);

        // Act
        await _hub.Heartbeat();

        // Assert
        NotificationHub.LastHeartbeats[userId].Should().BeAfter(initialHeartbeat);
    }

    [Fact]
    public async Task Heartbeat_未认证用户不应更新心跳()
    {
        // Arrange
        var mockContext = CreateMockContext(null, "conn_noauth");
        var mockGroups = CreateMockGroups();
        SetupHubContext(mockContext, mockGroups);

        // Act
        await _hub.Heartbeat();

        // Assert - 不应抛出异常，静默忽略
        // 无额外断言，仅验证不崩溃
    }

    [Fact]
    public async Task JoinFamilyGroup_应加入指定家庭组()
    {
        // Arrange
        var userId = Guid.NewGuid().ToString();
        var familyId = Guid.NewGuid();
        var mockContext = CreateMockContext(userId, "conn_family");
        var mockGroups = CreateMockGroups();
        SetupHubContext(mockContext, mockGroups);

        // Act
        await _hub.JoinFamilyGroup(familyId);

        // Assert
        mockGroups.Verify(g => g.AddToGroupAsync("conn_family", $"family_{familyId}", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task LeaveFamilyGroup_应离开指定家庭组()
    {
        // Arrange
        var userId = Guid.NewGuid().ToString();
        var familyId = Guid.NewGuid();
        var mockContext = CreateMockContext(userId, "conn_leave");
        var mockGroups = CreateMockGroups();
        SetupHubContext(mockContext, mockGroups);

        // Act
        await _hub.LeaveFamilyGroup(familyId);

        // Assert
        mockGroups.Verify(g => g.RemoveFromGroupAsync("conn_leave", $"family_{familyId}", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task OnlineUserCount_多用户连接应正确统计()
    {
        // 清理静态数据（测试隔离）
        ClearStaticData();

        // Arrange
        var userId1 = Guid.NewGuid().ToString();
        var userId2 = Guid.NewGuid().ToString();
        var mockGroups = CreateMockGroups();

        // 用户1连接
        var hub1 = new NotificationHub(_mockLogger.Object);
        hub1.Context = CreateMockContext(userId1, "conn_1").Object;
        hub1.Groups = mockGroups.Object;
        await hub1.OnConnectedAsync();

        // 用户2连接
        var hub2 = new NotificationHub(_mockLogger.Object);
        hub2.Context = CreateMockContext(userId2, "conn_2").Object;
        hub2.Groups = mockGroups.Object;
        await hub2.OnConnectedAsync();

        // Assert
        NotificationHub.OnlineUserCount.Should().Be(2);
        NotificationHub.TotalConnectionCount.Should().Be(2);
    }

    /// <summary>
    /// 清理静态数据（测试隔离）
    /// 使用反射清理 NotificationHub 的静态字段
    /// </summary>
    private void ClearStaticData()
    {
        var hubType = typeof(NotificationHub);

        // 清理 _onlineUsers
        var onlineUsersField = hubType.GetField("_onlineUsers", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        if (onlineUsersField?.GetValue(null) is ConcurrentDictionary<string, HashSet<string>> onlineUsers)
        {
            onlineUsers.Clear();
        }

        // 清理 _lastHeartbeat
        var lastHeartbeatField = hubType.GetField("_lastHeartbeat", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        if (lastHeartbeatField?.GetValue(null) is ConcurrentDictionary<string, DateTime> lastHeartbeat)
        {
            lastHeartbeat.Clear();
        }
    }
}