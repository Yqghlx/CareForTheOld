using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// FamilyService 单元测试
/// </summary>
public class FamilyServiceTests
{
    private readonly AppDbContext _context;
    private readonly FamilyService _service;

    public FamilyServiceTests()
    {
        // 使用 InMemory 数据库，GUID 命名确保测试隔离
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _service = new FamilyService(_context);
    }

    /// <summary>
    /// 创建一个用户实体并保存到数据库
    /// </summary>
    private async Task<User> CreateUserAsync(
        string phone = "13700001111",
        string name = "测试用户",
        UserRole role = UserRole.Child)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = phone,
            PasswordHash = "hash",
            RealName = name,
            BirthDate = new DateOnly(1990, 1, 1),
            Role = role
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    [Fact]
    public async Task CreateFamilyAsync_ShouldCreateWithInviteCode()
    {
        // 准备：创建一个用户作为家庭创建者
        var creator = await CreateUserAsync("13700001001", "家庭创建者", UserRole.Child);

        var request = new CreateFamilyRequest
        {
            FamilyName = "幸福之家"
        };

        // 执行：创建家庭
        var result = await _service.CreateFamilyAsync(creator.Id, request);

        // 验证：家庭创建成功，包含邀请码，创建者自动成为成员
        result.Should().NotBeNull();
        result.FamilyName.Should().Be("幸福之家");
        result.InviteCode.Should().NotBeNullOrEmpty();
        result.InviteCode.Should().MatchRegex(@"^\d{6}$"); // 6位数字邀请码
        result.Members.Should().HaveCount(1);
        result.Members[0].UserId.Should().Be(creator.Id);
        result.Members[0].Relation.Should().Be("创建者");
    }

    [Fact]
    public async Task JoinFamilyByCodeAsync_ShouldJoin()
    {
        // 准备：创建用户和家庭
        var creator = await CreateUserAsync("13700002001", "家庭创建者", UserRole.Child);
        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "加入测试家庭",
            CreatorId = creator.Id,
            InviteCode = "888888",
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Relation = "创建者"
        });
        await _context.SaveChangesAsync();

        // 创建要加入的用户
        var joiner = await CreateUserAsync("13700002002", "加入者", UserRole.Elder);

        var request = new JoinFamilyRequest
        {
            InviteCode = "888888",
            Relation = "父亲"
        };

        // 执行：通过邀请码加入家庭
        var result = await _service.JoinFamilyByCodeAsync(joiner.Id, request);

        // 验证：加入成功，家庭成员列表包含新成员
        result.Should().NotBeNull();
        result.Members.Should().HaveCount(2);
        result.Members.Should().Contain(m =>
            m.UserId == joiner.Id && m.Relation == "父亲" && m.Role == UserRole.Elder);
    }

    [Fact]
    public async Task JoinFamilyByCodeAsync_ShouldThrow_WhenInvalidCode()
    {
        // 准备：创建用户但没有对应邀请码的家庭
        var joiner = await CreateUserAsync("13700003001", "无效邀请码测试者");

        var request = new JoinFamilyRequest
        {
            InviteCode = "000000",
            Relation = "叔叔"
        };

        // 执行并验证：无效邀请码应抛出异常
        var act = async () => await _service.JoinFamilyByCodeAsync(joiner.Id, request);
        await act.Should().ThrowAsync<KeyNotFoundException>()
            .WithMessage("邀请码无效，请检查后重试");
    }

    [Fact]
    public async Task JoinFamilyByCodeAsync_ShouldThrow_WhenAlreadyInFamily()
    {
        // 准备：创建用户并加入一个家庭
        var creator = await CreateUserAsync("13700004001", "已有家庭成员");
        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "已有家庭",
            CreatorId = creator.Id,
            InviteCode = "111111",
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Relation = "创建者"
        });
        await _context.SaveChangesAsync();

        var request = new JoinFamilyRequest
        {
            InviteCode = "111111",
            Relation = "朋友"
        };

        // 执行并验证：已在家庭中的用户不能重复加入
        var act = async () => await _service.JoinFamilyByCodeAsync(creator.Id, request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("您已加入家庭组，不能重复加入");
    }

    [Fact]
    public async Task AddMemberAsync_ShouldAdd()
    {
        // 准备：创建家庭和操作者
        var operator_ = await CreateUserAsync("13700005001", "操作者");
        var targetUser = await CreateUserAsync("13700005002", "被添加用户", UserRole.Elder);

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "添加成员家庭",
            CreatorId = operator_.Id,
            InviteCode = "222222",
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = operator_.Id,
            Role = UserRole.Child,
            Relation = "创建者"
        });
        await _context.SaveChangesAsync();

        var request = new AddFamilyMemberRequest
        {
            PhoneNumber = "13700005002",
            Role = UserRole.Elder,
            Relation = "母亲"
        };

        // 执行：添加家庭成员
        var result = await _service.AddMemberAsync(family.Id, operator_.Id, request);

        // 验证：成员添加成功
        result.Should().NotBeNull();
        result.Members.Should().HaveCount(2);
        result.Members.Should().Contain(m =>
            m.UserId == targetUser.Id && m.Relation == "母亲" && m.Role == UserRole.Elder);
    }

    [Fact]
    public async Task RemoveMemberAsync_ShouldRemove()
    {
        // 准备：创建家庭和两个成员
        var operator_ = await CreateUserAsync("13700006001", "移除操作者");
        var member = await CreateUserAsync("13700006002", "待移除成员");

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "移除成员家庭",
            CreatorId = operator_.Id,
            InviteCode = "333333",
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);
        _context.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = operator_.Id,
                Role = UserRole.Child,
                Relation = "创建者"
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = member.Id,
                Role = UserRole.Elder,
                Relation = "父亲"
            }
        );
        await _context.SaveChangesAsync();

        // 执行：移除成员
        await _service.RemoveMemberAsync(family.Id, member.Id, operator_.Id);

        // 验证：成员已被移除
        var remaining = await _context.FamilyMembers
            .Where(fm => fm.FamilyId == family.Id)
            .ToListAsync();
        remaining.Should().HaveCount(1);
        remaining[0].UserId.Should().Be(operator_.Id);
    }

    [Fact]
    public async Task RefreshInviteCodeAsync_ShouldGenerateNewCode()
    {
        // 准备：创建家庭
        var creator = await CreateUserAsync("13700007001", "刷新邀请码用户");
        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "刷新测试家庭",
            CreatorId = creator.Id,
            InviteCode = "444444",
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Relation = "创建者"
        });
        await _context.SaveChangesAsync();

        // 执行：刷新邀请码
        var result = await _service.RefreshInviteCodeAsync(family.Id, creator.Id);

        // 验证：邀请码已更新（不再是原来的值）
        result.Should().NotBeNull();
        result.InviteCode.Should().NotBe("444444");
        result.InviteCode.Should().MatchRegex(@"^\d{6}$");
    }

    [Fact]
    public async Task RefreshInviteCodeAsync_ShouldThrow_WhenNotMember()
    {
        // 准备：创建家庭和一个非成员用户
        var creator = await CreateUserAsync("13700008001", "家庭创建者");
        var stranger = await CreateUserAsync("13700008002", "陌生人");

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "权限测试家庭",
            CreatorId = creator.Id,
            InviteCode = "555555",
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = creator.Id,
            Role = UserRole.Child,
            Relation = "创建者"
        });
        await _context.SaveChangesAsync();

        // 执行并验证：非家庭成员刷新邀请码应抛出权限异常
        var act = async () => await _service.RefreshInviteCodeAsync(family.Id, stranger.Id);
        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("您不是该家庭成员");
    }
}
