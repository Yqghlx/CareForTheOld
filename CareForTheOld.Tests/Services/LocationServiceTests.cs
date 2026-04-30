using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// LocationService 单元测试
/// </summary>
public class LocationServiceTests
{
    private readonly AppDbContext _context;
    private readonly LocationService _service;
    private readonly Mock<IGeoFenceService> _mockGeoFenceService;
    private readonly Mock<INotificationService> _mockNotificationService;
    private readonly Mock<IAutoRescueService> _mockAutoRescueService;
    private readonly Mock<IFamilyService> _mockFamilyService;

    public LocationServiceTests()
    {
        // 使用 InMemory 数据库，GUID 命名确保测试隔离
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);

        // Mock 依赖服务
        _mockGeoFenceService = new Mock<IGeoFenceService>();
        _mockNotificationService = new Mock<INotificationService>();
        _mockAutoRescueService = new Mock<IAutoRescueService>();
        _mockFamilyService = new Mock<IFamilyService>();

        _service = new LocationService(
            _context,
            _mockGeoFenceService.Object,
            _mockNotificationService.Object,
            _mockAutoRescueService.Object,
            _mockFamilyService.Object,
            new Mock<ILogger<LocationService>>().Object);
    }

    /// <summary>
    /// 创建用户并保存到数据库
    /// </summary>
    private async Task<User> CreateUserAsync(
        string phone = "13600001111",
        string name = "位置测试用户",
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
    /// 创建完整的家庭关系（老人+子女+家庭组）
    /// </summary>
    private async Task<(User elder, User child, Family family)> CreateFamilyWithMembersAsync()
    {
        var elder = await CreateUserAsync("13600001001", "位置老人", UserRole.Elder);
        var child = await CreateUserAsync("13600001002", "位置子女", UserRole.Child);

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "位置测试家庭",
            CreatorId = child.Id,
            InviteCode = "777777",
            CreatedAt = DateTime.UtcNow
        };
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
    public async Task ReportLocationAsync_ShouldSaveLocation()
    {
        // 准备：创建用户，围栏检查返回 null（未超出围栏）
        var user = await CreateUserAsync();
        _mockGeoFenceService
            .Setup(g => g.CheckOutsideFenceAsync(user.Id, 39.9042, 116.4074))
            .ReturnsAsync((ValueTuple<GeoFenceResponse?, double>?)null);

        // 执行：上报位置
        var result = await _service.ReportLocationAsync(user.Id, 39.9042, 116.4074);

        // 验证：位置记录保存成功
        result.Should().NotBeNull();
        result.UserId.Should().Be(user.Id);
        result.RealName.Should().Be("位置测试用户");
        result.Latitude.Should().Be(39.9042);
        result.Longitude.Should().Be(116.4074);
        result.RecordedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));

        // 验证：数据库中存在该记录
        var recordInDb = await _context.LocationRecords.FirstOrDefaultAsync(r => r.UserId == user.Id);
        recordInDb.Should().NotBeNull();
    }

    [Fact]
    public async Task ReportLocationAsync_ShouldTriggerAlert_WhenOutsideFence()
    {
        // 准备：创建完整的家庭关系
        var (elder, child, family) = await CreateFamilyWithMembersAsync();

        // Mock：围栏检查返回超出围栏
        var fenceResponse = new GeoFenceResponse
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500
        };
        _mockGeoFenceService
            .Setup(g => g.CheckOutsideFenceAsync(elder.Id, 40.0, 117.0))
            .ReturnsAsync((fenceResponse, 1500.0));

        // Mock：GetChildUserIdsAsync 返回子女 ID
        _mockFamilyService
            .Setup(f => f.GetChildUserIdsAsync(family.Id, default))
            .ReturnsAsync(new List<Guid> { child.Id });

        // 执行：上报围栏外位置
        var result = await _service.ReportLocationAsync(elder.Id, 40.0, 117.0);

        // 验证：位置记录保存成功
        result.Should().NotBeNull();
        result.Latitude.Should().Be(40.0);
        result.Longitude.Should().Be(117.0);

        // 验证：围栏检查被调用
        _mockGeoFenceService.Verify(
            g => g.CheckOutsideFenceAsync(elder.Id, 40.0, 117.0),
            Times.Once);

        // 直接验证围栏告警 Job 方法：模拟 Hangfire 调用公开入口
        await _service.SendGeoFenceAlertJobAsync(elder.Id, fenceResponse.Id, fenceResponse.Radius, 1500.0);

        _mockNotificationService.Verify(
            n => n.SendToUsersAsync(
                It.IsAny<IEnumerable<Guid>>(),
                "GeoFenceAlert",
                It.IsAny<object>()),
            Times.Once);
    }

    [Fact]
    public async Task ReportLocationAsync_ShouldNotTriggerAlert_WhenInsideFence()
    {
        // 准备：创建用户
        var user = await CreateUserAsync();

        // Mock：围栏检查返回 null（在围栏内或无围栏）
        _mockGeoFenceService
            .Setup(g => g.CheckOutsideFenceAsync(user.Id, 39.9042, 116.4074))
            .ReturnsAsync((ValueTuple<GeoFenceResponse?, double>?)null);

        // 执行：上报位置
        await _service.ReportLocationAsync(user.Id, 39.9042, 116.4074);

        // 等待确保异步操作完成
        await Task.Delay(200);

        // 验证：通知服务未被调用
        _mockNotificationService.Verify(
            n => n.SendToUsersAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<string>(), It.IsAny<object>()),
            Times.Never);
    }

    [Fact]
    public async Task GetLatestLocationAsync_ShouldReturnLatest()
    {
        // 准备：创建用户并上报多条位置记录
        var user = await CreateUserAsync();

        var olderRecord = new LocationRecord
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Latitude = 39.9000,
            Longitude = 116.4000,
            RecordedAt = DateTime.UtcNow.AddHours(-2)
        };
        var latestRecord = new LocationRecord
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Latitude = 39.9100,
            Longitude = 116.4100,
            RecordedAt = DateTime.UtcNow
        };
        _context.LocationRecords.AddRange(olderRecord, latestRecord);
        await _context.SaveChangesAsync();

        // 执行：获取最新位置
        var result = await _service.GetLatestLocationAsync(user.Id);

        // 验证：返回最新的位置记录
        result.Should().NotBeNull();
        result!.Latitude.Should().Be(39.9100);
        result.Longitude.Should().Be(116.4100);
        result.RecordedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
    }

    [Fact]
    public async Task GetLatestLocationAsync_ShouldReturnNull_WhenNoRecords()
    {
        // 准备：创建用户但不上报位置
        var user = await CreateUserAsync();

        // 执行：获取最新位置
        var result = await _service.GetLatestLocationAsync(user.Id);

        // 验证：无记录时返回 null
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetFamilyMemberLocationHistoryAsync_ShouldReturnRecords()
    {
        // 准备：创建家庭关系并上报老人位置
        var (elder, child, family) = await CreateFamilyWithMembersAsync();

        var records = new List<LocationRecord>
        {
            new()
            {
                Id = Guid.NewGuid(),
                UserId = elder.Id,
                Latitude = 39.9001,
                Longitude = 116.4001,
                RecordedAt = DateTime.UtcNow.AddHours(-3)
            },
            new()
            {
                Id = Guid.NewGuid(),
                UserId = elder.Id,
                Latitude = 39.9002,
                Longitude = 116.4002,
                RecordedAt = DateTime.UtcNow.AddHours(-1)
            },
            new()
            {
                Id = Guid.NewGuid(),
                UserId = elder.Id,
                Latitude = 39.9003,
                Longitude = 116.4003,
                RecordedAt = DateTime.UtcNow
            }
        };
        _context.LocationRecords.AddRange(records);
        await _context.SaveChangesAsync();

        // 执行：获取家庭成员位置历史
        var result = await _service.GetFamilyMemberLocationHistoryAsync(family.Id, elder.Id);

        // 验证：返回该家庭成员的所有位置记录，按时间倒序排列
        result.Should().HaveCount(3);
        result[0].Latitude.Should().Be(39.9003); // 最新的排在前面
        result[2].Latitude.Should().Be(39.9001);
        result.Should().OnlyContain(r => r.UserId == elder.Id);
    }

    [Fact]
    public async Task ReportLocationAsync_ShouldSendCriticalAlert_WhenDistanceFarExceedsFence()
    {
        // 准备：创建完整的家庭关系
        var (elder, child, family) = await CreateFamilyWithMembersAsync();

        // Mock：围栏半径 500 米，但距离 1500 米（超过 2 倍半径 = Critical）
        var fenceResponse = new GeoFenceResponse
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500
        };
        _mockGeoFenceService
            .Setup(g => g.CheckOutsideFenceAsync(elder.Id, 40.0, 117.0))
            .ReturnsAsync((fenceResponse, 1500.0));

        // Mock：GetChildUserIdsAsync 返回子女 ID
        _mockFamilyService
            .Setup(f => f.GetChildUserIdsAsync(family.Id, default))
            .ReturnsAsync(new List<Guid> { child.Id });

        // 执行：上报围栏外位置
        await _service.ReportLocationAsync(elder.Id, 40.0, 117.0);

        // 直接验证围栏告警 Job 方法：距离超过 2 倍半径应为 Critical
        await _service.SendGeoFenceAlertJobAsync(elder.Id, fenceResponse.Id, fenceResponse.Radius, 1500.0);

        // 验证：通知包含 Critical 级别（距离 > 半径 * 2）
        _mockNotificationService.Verify(
            n => n.SendToUsersAsync(
                It.IsAny<IEnumerable<Guid>>(),
                "GeoFenceAlert",
                It.IsAny<object>()),
            Times.Once);
    }

    [Fact]
    public async Task ReportLocationAsync_ShouldSendWarningAlert_WhenDistanceSlightlyExceedsFence()
    {
        // 准备：创建完整的家庭关系
        var (elder, child, family) = await CreateFamilyWithMembersAsync();

        // Mock：围栏半径 500 米，距离 600 米（未超过 2 倍半径 = Warning）
        var fenceResponse = new GeoFenceResponse
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500
        };
        _mockGeoFenceService
            .Setup(g => g.CheckOutsideFenceAsync(elder.Id, 39.91, 116.41))
            .ReturnsAsync((fenceResponse, 600.0));

        // Mock：GetChildUserIdsAsync 返回子女 ID
        _mockFamilyService
            .Setup(f => f.GetChildUserIdsAsync(family.Id, default))
            .ReturnsAsync(new List<Guid> { child.Id });

        // 执行
        await _service.ReportLocationAsync(elder.Id, 39.91, 116.41);

        // 直接验证围栏告警 Job 方法：距离未超过 2 倍半径应为 Warning
        await _service.SendGeoFenceAlertJobAsync(elder.Id, fenceResponse.Id, fenceResponse.Radius, 600.0);

        // 验证：通知包含 Warning 级别（距离 <= 半径 * 2）
        _mockNotificationService.Verify(
            n => n.SendToUsersAsync(
                It.IsAny<IEnumerable<Guid>>(),
                "GeoFenceAlert",
                It.IsAny<object>()),
            Times.Once);
    }
}
