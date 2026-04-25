using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Hangfire;
using Hangfire.MemoryStorage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// EmergencyService 单元测试
/// </summary>
public class EmergencyServiceTests
{
    private readonly AppDbContext _context;
    private readonly EmergencyService _service;
    private readonly Mock<INotificationService> _mockNotificationService;
    private readonly Mock<ISmsService> _mockSmsService;

    /// <summary>
    /// 初始化 Hangfire InMemory storage（测试环境需要）
    /// </summary>
    public EmergencyServiceTests()
    {
        // 配置 Hangfire 使用 InMemory storage
        JobStorage.Current = new MemoryStorage();

        // 使用 InMemory 数据库，GUID 命名确保测试隔离
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _mockNotificationService = new Mock<INotificationService>();
        _mockSmsService = new Mock<ISmsService>();
        // 设置 SMS 服务模拟返回成功
        _mockSmsService.Setup(s => s.SendAsync(It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync((true, null));
        _mockSmsService.SetupGet(s => s.ServiceName).Returns("MockSms");
        var mockLogger = new Mock<ILogger<EmergencyService>>();
        var mockNeighborHelpService = new Mock<INeighborHelpService>();
        _service = new EmergencyService(_context, _mockNotificationService.Object, _mockSmsService.Object, mockNeighborHelpService.Object, mockLogger.Object);
    }

    /// <summary>
    /// 创建基础测试数据：老人用户、子女用户、家庭组、家庭成员关系
    /// </summary>
    private async Task<(User elder, User child, Family family)> CreateTestDataAsync()
    {
        var elder = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800001111",
            PasswordHash = "hash",
            RealName = "测试老人",
            BirthDate = new DateOnly(1950, 1, 1),
            Role = UserRole.Elder
        };

        var child = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800002222",
            PasswordHash = "hash",
            RealName = "测试子女",
            BirthDate = new DateOnly(1990, 5, 15),
            Role = UserRole.Child
        };

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "测试家庭",
            CreatorId = child.Id,
            InviteCode = "123456",
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.AddRange(elder, child);
        _context.Families.Add(family);
        _context.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = elder.Id,
                Role = UserRole.Elder,
                Relation = "父亲",
                Status = FamilyMemberStatus.Approved
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = child.Id,
                Role = UserRole.Child,
                Relation = "儿子",
                Status = FamilyMemberStatus.Approved
            }
        );
        await _context.SaveChangesAsync();
        return (elder, child, family);
    }

    [Fact]
    public async Task CreateCallAsync_ShouldCreateCall_WhenElderInFamily()
    {
        // 准备：创建老人、子女、家庭组和成员关系
        var (elder, child, family) = await CreateTestDataAsync();

        // 执行：老人发起紧急呼叫
        var result = await _service.CreateCallAsync(elder.Id);

        // 验证：呼叫记录正确创建
        result.Should().NotBeNull();
        result.ElderId.Should().Be(elder.Id);
        result.FamilyId.Should().Be(family.Id);
        result.Status.Should().Be(EmergencyStatus.Pending);
        result.ElderName.Should().Be("测试老人");
        result.CalledAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));

        // 验证：数据库中存在该记录
        var callInDb = await _context.EmergencyCalls.FirstOrDefaultAsync(c => c.Id == result.Id);
        callInDb.Should().NotBeNull();
        callInDb!.ElderId.Should().Be(elder.Id);
        callInDb.Status.Should().Be(EmergencyStatus.Pending);
    }

    [Fact]
    public async Task CreateCallAsync_ShouldSaveLocationAndBattery()
    {
        // 准备：创建老人、子女、家庭组和成员关系
        var (elder, child, family) = await CreateTestDataAsync();

        // 执行：老人带位置和电量信息发起紧急呼叫
        var result = await _service.CreateCallAsync(elder.Id, latitude: 39.9042, longitude: 116.4074, batteryLevel: 75);

        // 验证：响应包含位置和电量信息
        result.Should().NotBeNull();
        result.Latitude.Should().Be(39.9042);
        result.Longitude.Should().Be(116.4074);
        result.BatteryLevel.Should().Be(75);

        // 验证：数据库中正确保存
        var callInDb = await _context.EmergencyCalls.FirstOrDefaultAsync(c => c.Id == result.Id);
        callInDb.Should().NotBeNull();
        callInDb!.Latitude.Should().Be(39.9042);
        callInDb!.Longitude.Should().Be(116.4074);
        callInDb!.BatteryLevel.Should().Be(75);
    }

    [Fact]
    public async Task CreateCallAsync_ShouldThrow_WhenElderNotInFamily()
    {
        // 准备：创建一个不在家庭组中的老人
        var loneElder = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800009999",
            PasswordHash = "hash",
            RealName = "孤独老人",
            BirthDate = new DateOnly(1945, 3, 10),
            Role = UserRole.Elder
        };
        _context.Users.Add(loneElder);
        await _context.SaveChangesAsync();

        // 执行并验证：不在家庭组中的老人发起呼叫应抛出异常
        var act = async () => await _service.CreateCallAsync(loneElder.Id);
        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("您不在任何家庭组中，无法发起紧急呼叫");
    }

    [Fact]
    public async Task RespondCallAsync_ShouldRespond_WhenFamilyMember()
    {
        // 准备：创建测试数据并产生一条待处理呼叫
        var (elder, child, family) = await CreateTestDataAsync();
        var call = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddMinutes(-5),
            Status = EmergencyStatus.Pending
        };
        _context.EmergencyCalls.Add(call);
        await _context.SaveChangesAsync();

        // 执行：子女响应呼叫
        var result = await _service.RespondCallAsync(call.Id, child.Id);

        // 验证：呼叫状态变为已响应，记录了响应者信息
        result.Should().NotBeNull();
        result.Status.Should().Be(EmergencyStatus.Responded);
        result.RespondedBy.Should().Be(child.Id);
        result.RespondedByRealName.Should().Be("测试子女");
        result.RespondedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
    }

    [Fact]
    public async Task RespondCallAsync_ShouldThrow_WhenAlreadyResponded()
    {
        // 准备：创建一条已响应的呼叫记录
        var (elder, child, family) = await CreateTestDataAsync();
        var call = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddMinutes(-10),
            Status = EmergencyStatus.Responded,
            RespondedBy = child.Id,
            RespondedByRealName = "测试子女",
            RespondedAt = DateTime.UtcNow.AddMinutes(-8)
        };
        _context.EmergencyCalls.Add(call);
        await _context.SaveChangesAsync();

        // 执行并验证：重复响应应抛出异常
        var act = async () => await _service.RespondCallAsync(call.Id, child.Id);
        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("该呼叫已被处理");
    }

    [Fact]
    public async Task RespondCallAsync_ShouldThrow_WhenNotFamilyMember()
    {
        // 准备：创建呼叫和一个非家庭成员（陌生人）
        var (elder, child, family) = await CreateTestDataAsync();
        var stranger = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800008888",
            PasswordHash = "hash",
            RealName = "陌生人",
            BirthDate = new DateOnly(1985, 7, 20),
            Role = UserRole.Child
        };
        _context.Users.Add(stranger);

        var call = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddMinutes(-3),
            Status = EmergencyStatus.Pending
        };
        _context.EmergencyCalls.Add(call);
        await _context.SaveChangesAsync();

        // 执行并验证：非家庭成员响应应抛出权限异常
        var act = async () => await _service.RespondCallAsync(call.Id, stranger.Id);
        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("您不是该家庭成员，无法处理此呼叫");
    }

    [Fact]
    public async Task RespondCallAsync_ShouldThrow_WhenCallNotFound()
    {
        // 准备：创建用户但不创建呼叫记录
        var (_, child, _) = await CreateTestDataAsync();
        var nonExistentCallId = Guid.NewGuid();

        // 执行并验证：呼叫不存在应抛出异常
        var act = async () => await _service.RespondCallAsync(nonExistentCallId, child.Id);
        await act.Should().ThrowAsync<KeyNotFoundException>()
            .WithMessage("紧急呼叫记录不存在");
    }

    [Fact]
    public async Task GetUnreadCallsAsync_ShouldReturnPending()
    {
        // 准备：创建两条待处理呼叫和一条已处理呼叫
        var (elder, child, family) = await CreateTestDataAsync();

        var pendingCall1 = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddMinutes(-20),
            Status = EmergencyStatus.Pending
        };
        var pendingCall2 = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddMinutes(-10),
            Status = EmergencyStatus.Pending
        };
        var respondedCall = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddMinutes(-30),
            Status = EmergencyStatus.Responded,
            RespondedBy = child.Id,
            RespondedAt = DateTime.UtcNow.AddMinutes(-25)
        };

        _context.EmergencyCalls.AddRange(pendingCall1, pendingCall2, respondedCall);
        await _context.SaveChangesAsync();

        // 执行：获取未处理呼叫
        var result = await _service.GetUnreadCallsAsync(child.Id);

        // 验证：仅返回待处理的呼叫
        result.Should().HaveCount(2);
        result.Should().OnlyContain(c => c.Status == EmergencyStatus.Pending);
        // 验证按时间倒序排列
        result[0].CalledAt.Should().BeAfter(result[1].CalledAt);
    }

    [Fact]
    public async Task GetHistoryAsync_ShouldReturnOrdered()
    {
        // 准备：创建多条呼叫记录（不同时间）
        var (elder, child, family) = await CreateTestDataAsync();

        var call1 = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddHours(-3),
            Status = EmergencyStatus.Responded,
            RespondedBy = child.Id,
            RespondedByRealName = "测试子女",
            RespondedAt = DateTime.UtcNow.AddHours(-2)
        };
        var call2 = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddHours(-1),
            Status = EmergencyStatus.Responded,
            RespondedBy = child.Id,
            RespondedByRealName = "测试子女",
            RespondedAt = DateTime.UtcNow.AddMinutes(-50)
        };
        var call3 = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            FamilyId = family.Id,
            CalledAt = DateTime.UtcNow.AddMinutes(-5),
            Status = EmergencyStatus.Pending
        };

        _context.EmergencyCalls.AddRange(call1, call2, call3);
        await _context.SaveChangesAsync();

        // 执行：获取历史记录
        var result = await _service.GetHistoryAsync(child.Id);

        // 验证：返回所有记录，按时间倒序排列
        result.Should().HaveCount(3);
        result[0].CalledAt.Should().BeAfter(result[1].CalledAt);
        result[1].CalledAt.Should().BeAfter(result[2].CalledAt);
        // 验证响应者信息正确填充
        result[0].Status.Should().Be(EmergencyStatus.Pending);
        result[2].RespondedByRealName.Should().Be("测试子女");
    }
}
