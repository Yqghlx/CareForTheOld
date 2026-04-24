using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// AutoRescueService 单元测试
/// </summary>
public class AutoRescueServiceTests
{
    private readonly AppDbContext _context;
    private readonly AutoRescueService _service;
    private readonly Mock<INotificationService> _mockNotification;
    private readonly IServiceScopeFactory _scopeFactory;

    public AutoRescueServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);

        _mockNotification = new Mock<INotificationService>();
        _mockNotification.Setup(n => n.SendToUsersAsync(
                It.IsAny<IEnumerable<Guid>>(), It.IsAny<string>(), It.IsAny<object>()))
            .Returns(Task.CompletedTask);

        // 创建真实的 ServiceScopeFactory
        var services = new ServiceCollection();
        services.AddSingleton(_context);
        services.AddSingleton(_mockNotification.Object);
        services.AddSingleton(new Mock<IEmergencyService>().Object);
        services.AddSingleton(new Mock<INeighborHelpService>().Object);
        var serviceProvider = services.BuildServiceProvider();
        _scopeFactory = serviceProvider.GetRequiredService<IServiceScopeFactory>();

        // 使用内存配置替代 Mock（Moq 无法 mock GetValue 扩展方法）
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                { "AutoRescue:Enabled", "true" },
                { "AutoRescue:DelayMinutes", "1" },
            })
            .Build();

        _service = new AutoRescueService(
            _scopeFactory,
            new Mock<ILogger<AutoRescueService>>().Object,
            config);
    }

    /// <summary>
    /// 创建测试用户
    /// </summary>
    private async Task<User> CreateUserAsync(
        string phone = "13800001111",
        string name = "测试用户",
        UserRole role = UserRole.Elder)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = phone,
            PasswordHash = "hash",
            RealName = name,
            BirthDate = new DateOnly(1955, 8, 10),
            Role = role
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    /// <summary>
    /// 创建测试家庭关系
    /// </summary>
    private async Task<(Family family, Guid elderId, Guid childId)> CreateTestFamilyAsync()
    {
        var elder = await CreateUserAsync("13800001111", "测试老人", UserRole.Elder);
        var child = await CreateUserAsync("13800002222", "测试子女", UserRole.Child);

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "测试家庭",
            InviteCode = "ABC123",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            CreatedAt = DateTime.UtcNow,
        };
        _context.Families.Add(family);

        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(), UserId = elder.Id, FamilyId = family.Id, Role = UserRole.Elder
        });
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(), UserId = child.Id, FamilyId = family.Id, Role = UserRole.Child
        });
        await _context.SaveChangesAsync();

        return (family, elder.Id, child.Id);
    }

    [Fact]
    public async Task StartRescueTimerAsync_创建救援记录()
    {
        var (family, elderId, _) = await CreateTestFamilyAsync();
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "测试圈",
            CreatorId = elderId,
            InviteCode = "123456",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            CenterLatitude = 39.9,
            CenterLongitude = 116.4,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(), UserId = elderId, CircleId = circle.Id
        });
        await _context.SaveChangesAsync();

        await _service.StartRescueTimerAsync(
            elderId, family.Id, circle.Id, RescueTriggerType.GeoFenceBreach);

        var record = await _context.AutoRescueRecords.FirstOrDefaultAsync();
        record.Should().NotBeNull();
        record!.Status.Should().Be(AutoRescueStatus.WaitingChildResponse);
        record.TriggerType.Should().Be(RescueTriggerType.GeoFenceBreach);
        record.ChildNotifiedAt.Should().NotBeNull();
    }

    [Fact]
    public async Task StartRescueTimerAsync_已有待处理记录_不重复创建()
    {
        var (family, elderId, _) = await CreateTestFamilyAsync();
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "测试圈",
            CreatorId = elderId,
            InviteCode = "123456",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            CenterLatitude = 39.9, CenterLongitude = 116.4,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(), UserId = elderId, CircleId = circle.Id
        });
        await _context.SaveChangesAsync();

        await _service.StartRescueTimerAsync(elderId, family.Id, circle.Id, RescueTriggerType.GeoFenceBreach);
        await _service.StartRescueTimerAsync(elderId, family.Id, circle.Id, RescueTriggerType.HeartbeatTimeout);

        var count = await _context.AutoRescueRecords.CountAsync();
        count.Should().Be(1);
    }

    [Fact]
    public async Task ChildRespondAsync_标记已响应()
    {
        var (family, elderId, childId) = await CreateTestFamilyAsync();
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "测试圈",
            CreatorId = elderId,
            InviteCode = "123456",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            CenterLatitude = 39.9, CenterLongitude = 116.4,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(), UserId = elderId, CircleId = circle.Id
        });
        await _context.SaveChangesAsync();

        await _service.StartRescueTimerAsync(elderId, family.Id, circle.Id, RescueTriggerType.GeoFenceBreach);

        var record = await _context.AutoRescueRecords.FirstAsync();
        await _service.ChildRespondAsync(record.Id, childId);

        var updated = await _context.AutoRescueRecords.FindAsync(record.Id);
        updated!.Status.Should().Be(AutoRescueStatus.ChildResponded);
        updated.ChildRespondedAt.Should().NotBeNull();
    }

    [Fact]
    public async Task ChildRespondAsync_非家庭成员_抛出异常()
    {
        var (family, elderId, _) = await CreateTestFamilyAsync();
        var stranger = await CreateUserAsync("13800009999", "陌生人", UserRole.Child);
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "测试圈",
            CreatorId = elderId,
            InviteCode = "123456",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            CenterLatitude = 39.9, CenterLongitude = 116.4,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(), UserId = elderId, CircleId = circle.Id
        });
        await _context.SaveChangesAsync();

        await _service.StartRescueTimerAsync(elderId, family.Id, circle.Id, RescueTriggerType.GeoFenceBreach);

        var record = await _context.AutoRescueRecords.FirstAsync();

        var act = async () => await _service.ChildRespondAsync(record.Id, stranger.Id);
        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task GetHistoryAsync_返回家庭救援记录()
    {
        var (family, elderId, _) = await CreateTestFamilyAsync();
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "测试圈",
            CreatorId = elderId,
            InviteCode = "123456",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            CenterLatitude = 39.9, CenterLongitude = 116.4,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(), UserId = elderId, CircleId = circle.Id
        });
        await _context.SaveChangesAsync();

        await _service.StartRescueTimerAsync(elderId, family.Id, circle.Id, RescueTriggerType.GeoFenceBreach);

        var history = await _service.GetHistoryAsync(family.Id);

        history.Should().HaveCount(1);
        history[0].ElderId.Should().Be(elderId);
        history[0].TriggerType.Should().Be(RescueTriggerType.GeoFenceBreach);
    }
}
