using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// GeoFenceService 单元测试
/// </summary>
public class GeoFenceServiceTests
{
    private readonly AppDbContext _context;
    private readonly GeoFenceService _service;

    public GeoFenceServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _service = new GeoFenceService(_context);
    }

    private async Task<Guid> CreateTestUserAsync(string realName = "测试老人", UserRole role = UserRole.Elder)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800138000",
            PasswordHash = "test_hash",
            RealName = realName,
            Role = role,
            CreatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user.Id;
    }

    private async Task<Guid> CreateTestFamilyAsync(Guid elderId, Guid childId)
    {
        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "测试家庭",
            InviteCode = "123456",
            CreatorId = childId,
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);

        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = elderId,
            Role = UserRole.Elder,
            Relation = "父亲"
        });

        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = childId,
            Role = UserRole.Child,
            Relation = "子女"
        });

        await _context.SaveChangesAsync();
        return family.Id;
    }

    [Fact]
    public async Task CreateFenceAsync_ShouldCreateFence_WhenValidRequest()
    {
        var elderId = await CreateTestUserAsync("老人");
        var childId = await CreateTestUserAsync("子女", UserRole.Child);
        await CreateTestFamilyAsync(elderId, childId);

        var request = new Models.DTOs.Requests.GeoFences.CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500,
            IsEnabled = true
        };

        var result = await _service.CreateFenceAsync(childId, request);

        result.Should().NotBeNull();
        result.ElderId.Should().Be(elderId);
        result.CenterLatitude.Should().Be(39.9042);
        result.CenterLongitude.Should().Be(116.4074);
        result.Radius.Should().Be(500);
        result.IsEnabled.Should().BeTrue();
    }

    [Fact]
    public async Task GetElderFenceAsync_ShouldReturnFence_WhenFenceExists()
    {
        var elderId = await CreateTestUserAsync("老人");
        var childId = await CreateTestUserAsync("子女", UserRole.Child);
        await CreateTestFamilyAsync(elderId, childId);

        await _service.CreateFenceAsync(childId, new Models.DTOs.Requests.GeoFences.CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500
        });

        var result = await _service.GetElderFenceAsync(elderId);

        result.Should().NotBeNull();
        result!.ElderId.Should().Be(elderId);
    }

    [Fact]
    public async Task GetElderFenceAsync_ShouldReturnNull_WhenNoFenceExists()
    {
        var elderId = await CreateTestUserAsync("老人");

        var result = await _service.GetElderFenceAsync(elderId);

        result.Should().BeNull();
    }

    [Fact]
    public async Task CheckOutsideFenceAsync_ShouldReturnNull_WhenInsideFence()
    {
        var elderId = await CreateTestUserAsync("老人");
        var childId = await CreateTestUserAsync("子女", UserRole.Child);
        await CreateTestFamilyAsync(elderId, childId);

        // 创建围栏（北京天安门附近）
        await _service.CreateFenceAsync(childId, new Models.DTOs.Requests.GeoFences.CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 39.9042,  // 天安门纬度
            CenterLongitude = 116.4074, // 天安门经度
            Radius = 1000 // 1公里半径
        });

        // 检查同位置（在天安门，应该在围栏内）
        var result = await _service.CheckOutsideFenceAsync(elderId, 39.9042, 116.4074);

        result.Should().BeNull();
    }

    [Fact]
    public async Task CheckOutsideFenceAsync_ShouldReturnFenceAndDistance_WhenOutsideFence()
    {
        var elderId = await CreateTestUserAsync("老人");
        var childId = await CreateTestUserAsync("子女", UserRole.Child);
        await CreateTestFamilyAsync(elderId, childId);

        // 创建围栏（北京天安门附近，半径100米）
        await _service.CreateFenceAsync(childId, new Models.DTOs.Requests.GeoFences.CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 100 // 100米半径
        });

        // 检查距离500米外的位置（应该超出围栏）
        // 纬度每度约111公里，0.005度约555米
        var result = await _service.CheckOutsideFenceAsync(elderId, 39.9092, 116.4074);

        result.Should().NotBeNull();
        result!.Value.fence.Should().NotBeNull();
        result.Value.fence!.ElderId.Should().Be(elderId);
        result.Value.distance.Should().BeGreaterThan(100);
    }

    [Fact]
    public async Task CheckOutsideFenceAsync_ShouldReturnNull_WhenNoFenceExists()
    {
        var elderId = await CreateTestUserAsync("老人");

        var result = await _service.CheckOutsideFenceAsync(elderId, 39.9042, 116.4074);

        result.Should().BeNull();
    }

    [Fact]
    public async Task CheckOutsideFenceAsync_ShouldReturnNull_WhenFenceIsDisabled()
    {
        var elderId = await CreateTestUserAsync("老人");
        var childId = await CreateTestUserAsync("子女", UserRole.Child);
        await CreateTestFamilyAsync(elderId, childId);

        await _service.CreateFenceAsync(childId, new Models.DTOs.Requests.GeoFences.CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 100,
            IsEnabled = false // 禁用围栏
        });

        var result = await _service.CheckOutsideFenceAsync(elderId, 39.9092, 116.4074);

        result.Should().BeNull();
    }

    [Fact]
    public void CalculateDistance_ShouldCalculateCorrectly_ForNearbyPoints()
    {
        // 北京天安门到故宫（约1公里）
        var distance = GeoFenceService.CalculateDistance(
            39.9042, 116.4074,  // 天安门
            39.9163, 116.3972   // 故宫
        );

        // 实际距离约1.5公里，允许误差
        distance.Should().BeGreaterThan(1000);
        distance.Should().BeLessThan(2000);
    }

    [Fact]
    public void CalculateDistance_ShouldReturnZero_ForSamePoint()
    {
        var distance = GeoFenceService.CalculateDistance(39.9042, 116.4074, 39.9042, 116.4074);

        distance.Should().BeApproximately(0, 1);
    }

    [Fact]
    public async Task DeleteFenceAsync_ShouldDeleteFence_WhenAuthorized()
    {
        var elderId = await CreateTestUserAsync("老人");
        var childId = await CreateTestUserAsync("子女", UserRole.Child);
        await CreateTestFamilyAsync(elderId, childId);

        var fence = await _service.CreateFenceAsync(childId, new Models.DTOs.Requests.GeoFences.CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500
        });

        await _service.DeleteFenceAsync(fence.Id, childId);

        var result = await _service.GetElderFenceAsync(elderId);
        result.Should().BeNull();
    }

    [Fact]
    public async Task CreateFenceAsync_ShouldUpdateExistingFence_WhenFenceAlreadyExists()
    {
        var elderId = await CreateTestUserAsync("老人");
        var childId = await CreateTestUserAsync("子女", UserRole.Child);
        await CreateTestFamilyAsync(elderId, childId);

        // 创建第一个围栏
        await _service.CreateFenceAsync(childId, new Models.DTOs.Requests.GeoFences.CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500
        });

        // 再次创建（应该更新）
        var result = await _service.CreateFenceAsync(childId, new Models.DTOs.Requests.GeoFences.CreateGeoFenceRequest
        {
            ElderId = elderId,
            CenterLatitude = 40.0,
            CenterLongitude = 117.0,
            Radius = 1000
        });

        result.Radius.Should().Be(1000);
        result.CenterLatitude.Should().Be(40.0);

        // 应该只有一个围栏
        var allFences = await _context.GeoFences.Where(f => f.ElderId == elderId).ToListAsync();
        allFences.Should().HaveCount(1);
    }
}