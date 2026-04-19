using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.GeoFences;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Integration;

/// <summary>
/// GeoFenceService 集成测试（真实 PostgreSQL）
/// 验证 ElderId 唯一约束确保每个老人只有一个围栏
/// </summary>
[Collection("PostgreSql")]
public class GeoFenceServiceIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlFixture _fixture;
    private AppDbContext _context = null!;
    private GeoFenceService _service = null!;
    private Mock<ICacheService> _mockCacheService = null!;

    public GeoFenceServiceIntegrationTests(PostgreSqlFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        _context = _fixture.CreateDbContext();
        await _context.Database.EnsureCreatedAsync();

        // Mock ICacheService：集成测试关注数据库行为，缓存侧不影响
        _mockCacheService = new Mock<ICacheService>();
        _mockCacheService
            .Setup(c => c.RemoveAsync(It.IsAny<string>()))
            .Returns(Task.CompletedTask);
        _mockCacheService
            .Setup(c => c.GetOrCreateAsync<GeoFenceCacheEntry>(It.IsAny<string>(), It.IsAny<Func<Task<GeoFenceCacheEntry?>>>(), It.IsAny<TimeSpan?>()))
            .Returns((string _, Func<Task<GeoFenceCacheEntry?>> factory, TimeSpan? _) => factory());

        _service = new GeoFenceService(_context, _mockCacheService.Object);
    }

    public Task DisposeAsync()
    {
        _context.Dispose();
        return Task.CompletedTask;
    }

    private static int _phoneCounter = 100;
    private readonly object _phoneLock = new();

    private string NextPhone()
    {
        lock (_phoneLock) { return $"1390000{(_phoneCounter++):D4}"; }
    }

    /// <summary>
    /// 辅助：创建完整的家庭关系（老人+子女+家庭组）
    /// </summary>
    private async Task<(User elder, User child)> CreateFamilyPairAsync()
    {
        var elder = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = NextPhone(),
            PasswordHash = "hash",
            RealName = "围栏老人",
            BirthDate = new DateOnly(1950, 1, 1),
            Role = UserRole.Elder
        };
        var child = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = NextPhone(),
            PasswordHash = "hash",
            RealName = "围栏子女",
            BirthDate = new DateOnly(1990, 1, 1),
            Role = UserRole.Child
        };
        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "围栏测试家庭",
            CreatorId = child.Id,
            InviteCode = "999999",
            CreatedAt = DateTime.UtcNow
        };
        _context.Users.AddRange(elder, child);
        _context.Families.Add(family);
        _context.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = family.Id, UserId = elder.Id, Role = UserRole.Elder, Relation = "父亲" },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = family.Id, UserId = child.Id, Role = UserRole.Child, Relation = "子女" }
        );
        await _context.SaveChangesAsync();
        return (elder, child);
    }

    [Fact]
    public async Task CreateFenceAsync_ShouldEnforceUniqueConstraint_OnElderId()
    {
        // 准备：创建围栏
        var (elder, child) = await CreateFamilyPairAsync();
        await _service.CreateFenceAsync(child.Id, new CreateGeoFenceRequest
        {
            ElderId = elder.Id,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500
        });

        // 验证：数据库中只有一条围栏记录（更新语义，不是新增）
        var fences = await _context.GeoFences.Where(f => f.ElderId == elder.Id).ToListAsync();
        fences.Should().HaveCount(1);
    }

    [Fact]
    public async Task CreateFenceAsync_ShouldUpdateExistingFence()
    {
        // 准备
        var (elder, child) = await CreateFamilyPairAsync();

        // 第一次创建
        await _service.CreateFenceAsync(child.Id, new CreateGeoFenceRequest
        {
            ElderId = elder.Id,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            Radius = 500
        });

        // 第二次创建（应更新而非新增）
        var result = await _service.CreateFenceAsync(child.Id, new CreateGeoFenceRequest
        {
            ElderId = elder.Id,
            CenterLatitude = 40.0,
            CenterLongitude = 117.0,
            Radius = 1000
        });

        // 验证：值已更新
        result.CenterLatitude.Should().Be(40.0);
        result.Radius.Should().Be(1000);

        // 验证：数据库中仍只有一条围栏
        var fences = await _context.GeoFences.Where(f => f.ElderId == elder.Id).ToListAsync();
        fences.Should().HaveCount(1);
    }

    [Fact]
    public async Task CreateFenceAsync_ShouldPreventConcurrentDuplicate()
    {
        // 准备
        var (elder, child) = await CreateFamilyPairAsync();

        // 执行：并发创建两个围栏
        var task1 = Task.Run(async () =>
        {
            using var ctx = _fixture.CreateDbContext();
            await ctx.Database.EnsureCreatedAsync();
            var cache = new Mock<ICacheService>();
            cache.Setup(c => c.RemoveAsync(It.IsAny<string>())).Returns(Task.CompletedTask);
            var svc = new GeoFenceService(ctx, cache.Object);
            return await svc.CreateFenceAsync(child.Id, new CreateGeoFenceRequest
            {
                ElderId = elder.Id,
                CenterLatitude = 39.9042,
                CenterLongitude = 116.4074,
                Radius = 500
            });
        });

        var task2 = Task.Run(async () =>
        {
            using var ctx = _fixture.CreateDbContext();
            await ctx.Database.EnsureCreatedAsync();
            var cache = new Mock<ICacheService>();
            cache.Setup(c => c.RemoveAsync(It.IsAny<string>())).Returns(Task.CompletedTask);
            var svc = new GeoFenceService(ctx, cache.Object);
            return await svc.CreateFenceAsync(child.Id, new CreateGeoFenceRequest
            {
                ElderId = elder.Id,
                CenterLatitude = 40.0,
                CenterLongitude = 117.0,
                Radius = 1000
            });
        });

        // 验证：两个都应完成（更新语义），数据库最终只有一条围栏
        await Task.WhenAll(task1, task2);

        using var verifyCtx = _fixture.CreateDbContext();
        await verifyCtx.Database.EnsureCreatedAsync();
        var fences = await verifyCtx.GeoFences.Where(f => f.ElderId == elder.Id).ToListAsync();
        fences.Should().HaveCount(1, "ElderId 唯一约束保证每个老人只有一个围栏");
    }
}
