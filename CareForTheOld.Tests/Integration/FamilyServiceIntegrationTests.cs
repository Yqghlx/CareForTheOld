using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Families;
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
/// FamilyService 集成测试（真实 PostgreSQL）
/// 验证唯一约束在高并发场景下的数据一致性保护
/// </summary>
[Collection("PostgreSql")]
public class FamilyServiceIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlFixture _fixture;
    private AppDbContext _context = null!;
    private FamilyService _service = null!;
    private readonly Mock<INotificationService> _mockNotification = new();

    public FamilyServiceIntegrationTests(PostgreSqlFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        _context = _fixture.CreateDbContext();
        // 确保表结构最新
        await _context.Database.EnsureCreatedAsync();
        _service = new FamilyService(_context, _mockNotification.Object);
    }

    public Task DisposeAsync()
    {
        _context.Dispose();
        return Task.CompletedTask;
    }

    /// <summary>
    /// 辅助：创建用户并保存
    /// </summary>
    private async Task<User> CreateUserAsync(string phone, string name, UserRole role)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = phone,
            PasswordHash = "hash",
            RealName = name,
            BirthDate = new DateOnly(1950, 1, 1),
            Role = role
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    [Fact]
    public async Task CreateFamilyAsync_ShouldEnforceUniqueConstraint_OnUserId()
    {
        // 准备：创建一个用户并创建家庭
        var creator = await CreateUserAsync("13900001001", "测试用户", UserRole.Child);
        await _service.CreateFamilyAsync(creator.Id, new CreateFamilyRequest
        {
            FamilyName = "第一个家庭",
        });

        // 执行并验证：同一用户尝试创建第二个家庭应被拒绝
        var act = async () => await _service.CreateFamilyAsync(creator.Id, new CreateFamilyRequest
        {
            FamilyName = "第二个家庭",
        });
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*已加入家庭组*");
    }

    [Fact]
    public async Task CreateFamilyAsync_ShouldPreventConcurrentCreation()
    {
        // 准备：创建用户（不加入任何家庭）
        var user = await CreateUserAsync("13900001002", "并发测试用户", UserRole.Child);

        // 执行：同时发起两个创建家庭请求
        var task1 = Task.Run(async () =>
        {
            using var ctx = _fixture.CreateDbContext();
            await ctx.Database.EnsureCreatedAsync();
            var mockN = new Mock<INotificationService>();
            var svc = new FamilyService(ctx, mockN.Object);
            return await svc.CreateFamilyAsync(user.Id, new CreateFamilyRequest { FamilyName = "家庭A" });
        });

        var task2 = Task.Run(async () =>
        {
            using var ctx = _fixture.CreateDbContext();
            await ctx.Database.EnsureCreatedAsync();
            var mockN = new Mock<INotificationService>();
            var svc = new FamilyService(ctx, mockN.Object);
            return await svc.CreateFamilyAsync(user.Id, new CreateFamilyRequest { FamilyName = "家庭B" });
        });

        // 验证：至少一个请求应失败（唯一约束保护）
        var results = await Task.WhenAll(
            task1.ContinueWith(t => t.IsFaulted),
            task2.ContinueWith(t => t.IsFaulted)
        );

        // 不可能两个都成功（UserId 唯一约束）
        results.Should().Contain(true, "并发创建家庭时至少一个请求应被唯一约束阻止");
    }

    [Fact]
    public async Task JoinFamilyByCodeAsync_ShouldEnforceUniqueConstraint_OnUserId()
    {
        // 准备：用户 A 创建家庭，用户 B 申请加入
        var creator = await CreateUserAsync("13900001003", "创建者", UserRole.Child);
        var joiner = await CreateUserAsync("13900001004", "加入者", UserRole.Elder);
        var family = await _service.CreateFamilyAsync(creator.Id, new CreateFamilyRequest { FamilyName = "测试家庭" });

        // 申请加入家庭（Pending 状态，但已写入 FamilyMember 记录）
        await _service.JoinFamilyByCodeAsync(joiner.Id, new JoinFamilyRequest
        {
            InviteCode = family.InviteCode,
            Relation = "父亲"
        });

        // 执行并验证：再次尝试加入另一个家庭应被拒绝（已有 FamilyMember 记录）
        var creator2 = await CreateUserAsync("13900001005", "创建者2", UserRole.Child);
        var family2 = await _service.CreateFamilyAsync(creator2.Id, new CreateFamilyRequest { FamilyName = "另一个家庭" });

        var act = async () => await _service.JoinFamilyByCodeAsync(joiner.Id, new JoinFamilyRequest
        {
            InviteCode = family2.InviteCode,
            Relation = "父亲"
        });
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*已提交加入申请或已加入家庭组*");
    }

    [Fact]
    public async Task AddMemberAsync_ShouldRejectUserAlreadyInOtherFamily()
    {
        // 准备：用户 B 通过 AddMember 直接加入家庭 A（跳过审批，Status=Approved）
        var creatorA = await CreateUserAsync("13900001006", "家庭A创建者", UserRole.Child);
        var userB = await CreateUserAsync("13900001007", "用户B", UserRole.Elder);
        var familyA = await _service.CreateFamilyAsync(creatorA.Id, new CreateFamilyRequest { FamilyName = "家庭A" });
        await _service.AddMemberAsync(familyA.Id, creatorA.Id,
            new AddFamilyMemberRequest { PhoneNumber = userB.PhoneNumber, Relation = "父亲", Role = UserRole.Elder });

        // 准备：用户 C 创建家庭 B
        var creatorC = await CreateUserAsync("13900001008", "家庭B创建者", UserRole.Child);
        var familyB = await _service.CreateFamilyAsync(creatorC.Id, new CreateFamilyRequest { FamilyName = "家庭B" });

        // 执行并验证：尝试将用户 B（已在家庭A中）加入家庭 B 应被拒绝
        var act = async () => await _service.AddMemberAsync(familyB.Id, creatorC.Id,
            new AddFamilyMemberRequest { PhoneNumber = userB.PhoneNumber, Relation = "父亲", Role = UserRole.Elder });
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*已加入其他家庭组*");
    }
}
