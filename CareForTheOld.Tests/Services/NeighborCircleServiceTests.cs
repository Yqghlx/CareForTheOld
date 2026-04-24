using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// NeighborCircleService 单元测试
/// </summary>
public class NeighborCircleServiceTests
{
    private readonly AppDbContext _context;
    private readonly NeighborCircleService _service;

    public NeighborCircleServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _service = new NeighborCircleService(_context);
    }

    /// <summary>
    /// 创建一个用户实体并保存到数据库
    /// </summary>
    private async Task<User> CreateUserAsync(
        string phone = "13800001111",
        string name = "测试用户",
        UserRole role = UserRole.Child)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = phone,
            PasswordHash = "hash",
            RealName = name,
            BirthDate = new DateOnly(1960, 1, 1),
            Role = role
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    [Fact]
    public async Task CreateCircleAsync_应创建圈子并生成邀请码()
    {
        // 准备
        var creator = await CreateUserAsync("13800001001", "圈主", UserRole.Child);

        var request = new CreateNeighborCircleRequest
        {
            CircleName = "阳光小区互助群",
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            RadiusMeters = 500
        };

        // 执行
        var result = await _service.CreateCircleAsync(creator.Id, request);

        // 验证
        result.Should().NotBeNull();
        result.CircleName.Should().Be("阳光小区互助群");
        result.InviteCode.Should().NotBeNullOrEmpty();
        result.InviteCode.Should().MatchRegex(@"^\d{6}$");
        result.CreatorId.Should().Be(creator.Id);
        result.MemberCount.Should().Be(1);
        result.IsActive.Should().BeTrue();
    }

    [Fact]
    public async Task CreateCircleAsync_创建者应自动成为成员()
    {
        // 准备
        var creator = await CreateUserAsync("13800001002", "自动加入测试", UserRole.Elder);

        var request = new CreateNeighborCircleRequest
        {
            CircleName = "测试圈",
            CenterLatitude = 39.9,
            CenterLongitude = 116.4,
        };

        // 执行
        await _service.CreateCircleAsync(creator.Id, request);

        // 验证：创建者应该是圈子成员
        var members = await _service.GetMembersAsync(
            (await _context.NeighborCircles.FirstAsync()).Id);
        members.Should().HaveCount(1);
        members[0].UserId.Should().Be(creator.Id);
    }

    [Fact]
    public async Task CreateCircleAsync_已加入圈子应抛出异常()
    {
        // 准备：先创建一个圈子
        var creator = await CreateUserAsync("13800001003", "重复创建测试");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "已有圈子",
            CreatorId = creator.Id,
            InviteCode = "111111",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Status = NeighborCircleStatus.Approved,
        });
        await _context.SaveChangesAsync();

        var request = new CreateNeighborCircleRequest
        {
            CircleName = "新圈子",
            CenterLatitude = 39.9,
            CenterLongitude = 116.4,
        };

        // 执行并验证
        var act = async () => await _service.CreateCircleAsync(creator.Id, request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("您已加入邻里圈，不能重复创建");
    }

    [Fact]
    public async Task JoinCircleByCodeAsync_应通过邀请码加入()
    {
        // 准备：创建圈子和邀请码
        var creator = await CreateUserAsync("13800002001", "圈主");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "邀请码加入测试",
            CreatorId = creator.Id,
            InviteCode = "888888",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Status = NeighborCircleStatus.Approved,
        });
        await _context.SaveChangesAsync();

        var joiner = await CreateUserAsync("13800002002", "加入者", UserRole.Elder);

        var request = new JoinNeighborCircleRequest { InviteCode = "888888" };

        // 执行
        var result = await _service.JoinCircleByCodeAsync(joiner.Id, request);

        // 验证
        result.Should().NotBeNull();
        result.MemberCount.Should().Be(2);
    }

    [Fact]
    public async Task JoinCircleByCodeAsync_无效邀请码应抛出异常()
    {
        // 准备
        var user = await CreateUserAsync("13800002003", "无效码测试");

        var request = new JoinNeighborCircleRequest { InviteCode = "000000" };

        // 执行并验证
        var act = async () => await _service.JoinCircleByCodeAsync(user.Id, request);
        await act.Should().ThrowAsync<KeyNotFoundException>()
            .WithMessage("邀请码无效，请检查后重试");
    }

    [Fact]
    public async Task JoinCircleByCodeAsync_过期邀请码应抛出异常()
    {
        // 准备：邀请码已过期
        var creator = await CreateUserAsync("13800002004", "过期测试圈主");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "过期码测试",
            CreatorId = creator.Id,
            InviteCode = "999999",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(-1), // 已过期
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Status = NeighborCircleStatus.Approved,
        });
        await _context.SaveChangesAsync();

        var joiner = await CreateUserAsync("13800002005", "过期码加入者");

        var request = new JoinNeighborCircleRequest { InviteCode = "999999" };

        // 执行并验证
        var act = async () => await _service.JoinCircleByCodeAsync(joiner.Id, request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("邀请码已过期，请联系圈主获取新邀请码");
    }

    [Fact]
    public async Task JoinCircleByCodeAsync_已加入圈子应抛出异常()
    {
        // 准备
        var creator = await CreateUserAsync("13800002006", "重复加入圈主");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "重复加入测试",
            CreatorId = creator.Id,
            InviteCode = "777777",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Status = NeighborCircleStatus.Approved,
        });
        await _context.SaveChangesAsync();

        var request = new JoinNeighborCircleRequest { InviteCode = "777777" };

        // 执行并验证
        var act = async () => await _service.JoinCircleByCodeAsync(creator.Id, request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("您已加入邻里圈，不能重复加入");
    }

    [Fact]
    public async Task LeaveCircleAsync_普通成员退出应从圈子移除()
    {
        // 准备
        var creator = await CreateUserAsync("13800003001", "圈主");
        var member = await CreateUserAsync("13800003002", "退出者");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "退出测试",
            CreatorId = creator.Id,
            InviteCode = "666666",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.AddRange(
            new NeighborCircleMember
            {
                Id = Guid.NewGuid(), CircleId = circle.Id, UserId = creator.Id,
                Role = UserRole.Child, Status = NeighborCircleStatus.Approved,
            },
            new NeighborCircleMember
            {
                Id = Guid.NewGuid(), CircleId = circle.Id, UserId = member.Id,
                Role = UserRole.Elder, Status = NeighborCircleStatus.Approved,
            }
        );
        await _context.SaveChangesAsync();

        // 执行
        await _service.LeaveCircleAsync(circle.Id, member.Id);

        // 验证：退出者应被移除
        var members = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == circle.Id).ToListAsync();
        members.Should().HaveCount(1);
        members[0].UserId.Should().Be(creator.Id);
    }

    [Fact]
    public async Task LeaveCircleAsync_创建者退出应解散圈子()
    {
        // 准备
        var creator = await CreateUserAsync("13800003003", "解散圈主");
        var member = await CreateUserAsync("13800003004", "解散测试成员");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "解散测试",
            CreatorId = creator.Id,
            InviteCode = "555555",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.AddRange(
            new NeighborCircleMember
            {
                Id = Guid.NewGuid(), CircleId = circle.Id, UserId = creator.Id,
                Role = UserRole.Child, Status = NeighborCircleStatus.Approved,
            },
            new NeighborCircleMember
            {
                Id = Guid.NewGuid(), CircleId = circle.Id, UserId = member.Id,
                Role = UserRole.Elder, Status = NeighborCircleStatus.Approved,
            }
        );
        await _context.SaveChangesAsync();

        // 执行
        await _service.LeaveCircleAsync(circle.Id, creator.Id);

        // 验证：圈子应被标记为不活跃，所有成员移除
        var trackedCircle = await _context.NeighborCircles.FindAsync(circle.Id);
        trackedCircle!.IsActive.Should().BeFalse();

        var remaining = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == circle.Id).ToListAsync();
        remaining.Should().BeEmpty();
    }

    [Fact]
    public async Task GetMyCircleAsync_应返回用户加入的圈子()
    {
        // 准备
        var user = await CreateUserAsync("13800004001", "我的圈子测试");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "我的圈子",
            CreatorId = user.Id,
            InviteCode = "444444",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = user.Id,
            Role = UserRole.Child,
            Status = NeighborCircleStatus.Approved,
        });
        await _context.SaveChangesAsync();

        // 执行
        var result = await _service.GetMyCircleAsync(user.Id);

        // 验证
        result.Should().NotBeNull();
        result!.CircleName.Should().Be("我的圈子");
    }

    [Fact]
    public async Task GetMyCircleAsync_未加入应返回null()
    {
        // 准备
        var user = await CreateUserAsync("13800004002", "无圈子用户");

        // 执行
        var result = await _service.GetMyCircleAsync(user.Id);

        // 验证
        result.Should().BeNull();
    }

    [Fact]
    public async Task RefreshInviteCodeAsync_应生成新的邀请码()
    {
        // 准备
        var creator = await CreateUserAsync("13800005001", "刷新码圈主");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "刷新码测试",
            CreatorId = creator.Id,
            InviteCode = "333333",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Status = NeighborCircleStatus.Approved,
        });
        await _context.SaveChangesAsync();

        // 执行
        var result = await _service.RefreshInviteCodeAsync(circle.Id, creator.Id);

        // 验证
        result.InviteCode.Should().NotBe("333333");
        result.InviteCode.Should().MatchRegex(@"^\d{6}$");
    }

    [Fact]
    public async Task RefreshInviteCodeAsync_非圈主应抛出异常()
    {
        // 准备
        var creator = await CreateUserAsync("13800005002", "圈主");
        var member = await CreateUserAsync("13800005003", "非圈主");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "权限测试",
            CreatorId = creator.Id,
            InviteCode = "222222",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.AddRange(
            new NeighborCircleMember
            {
                Id = Guid.NewGuid(), CircleId = circle.Id, UserId = creator.Id,
                Role = UserRole.Child, Status = NeighborCircleStatus.Approved,
            },
            new NeighborCircleMember
            {
                Id = Guid.NewGuid(), CircleId = circle.Id, UserId = member.Id,
                Role = UserRole.Elder, Status = NeighborCircleStatus.Approved,
            }
        );
        await _context.SaveChangesAsync();

        // 执行并验证
        var act = async () => await _service.RefreshInviteCodeAsync(circle.Id, member.Id);
        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("仅圈主可以刷新邀请码");
    }

    [Fact]
    public async Task EnsureCircleMemberAsync_非成员应抛出异常()
    {
        // 准备
        var user = await CreateUserAsync("13800006001", "非成员");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "验证测试",
            CreatorId = Guid.NewGuid(),
            InviteCode = "111111",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        await _context.SaveChangesAsync();

        // 执行并验证
        var act = async () => await _service.EnsureCircleMemberAsync(circle.Id, user.Id);
        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("您不是该邻里圈成员");
    }

    [Fact]
    public async Task SearchNearbyCirclesAsync_应返回附近活跃圈子()
    {
        // 准备：创建圈子在北京市中心附近
        var creator = await CreateUserAsync("13800007001", "搜索圈主");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "附近圈子",
            CreatorId = creator.Id,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            RadiusMeters = 500,
            InviteCode = "123456",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Status = NeighborCircleStatus.Approved,
        });
        await _context.SaveChangesAsync();

        // 执行：从附近位置搜索
        var results = await _service.SearchNearbyCirclesAsync(39.9042, 116.4074, 1000);

        // 验证
        results.Should().NotBeEmpty();
        results[0].CircleName.Should().Be("附近圈子");
        results[0].DistanceMeters.Should().BeApproximately(0, 1);
    }

    [Fact]
    public async Task SearchNearbyCirclesAsync_不活跃圈子不应出现在结果中()
    {
        // 准备
        var creator = await CreateUserAsync("13800007002", "不活跃圈主");
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "不活跃圈子",
            CreatorId = creator.Id,
            CenterLatitude = 39.9042,
            CenterLongitude = 116.4074,
            RadiusMeters = 500,
            InviteCode = "654321",
            IsActive = false, // 不活跃
        };
        _context.NeighborCircles.Add(circle);
        await _context.SaveChangesAsync();

        // 执行
        var results = await _service.SearchNearbyCirclesAsync(39.9042, 116.4074, 1000);

        // 验证
        results.Should().BeEmpty();
    }
}
