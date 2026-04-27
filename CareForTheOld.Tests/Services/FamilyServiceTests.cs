using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// FamilyService 单元测试
/// </summary>
public class FamilyServiceTests
{
    private readonly AppDbContext _context;
    private readonly FamilyService _service;
    private readonly Mock<INotificationService> _mockNotification;

    public FamilyServiceTests()
    {
        // 使用 InMemory 数据库，GUID 命名确保测试隔离
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _mockNotification = new Mock<INotificationService>();
        _service = new FamilyService(_context, _mockNotification.Object, NullLogger<FamilyService>.Instance);
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
    public async Task JoinFamilyByCodeAsync_ShouldCreatePendingMember()
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
            Relation = "创建者",
            Status = FamilyMemberStatus.Approved
        });
        await _context.SaveChangesAsync();

        // 创建要加入的用户
        var joiner = await CreateUserAsync("13700002002", "加入者", UserRole.Elder);

        var request = new JoinFamilyRequest
        {
            InviteCode = "888888",
            Relation = "父亲"
        };

        // 执行：通过邀请码申请加入家庭
        var result = await _service.JoinFamilyByCodeAsync(joiner.Id, request);

        // 验证：返回申请结果，状态为 Pending
        result.Should().NotBeNull();
        result.Status.Should().Be(FamilyMemberStatus.Pending);
        result.Message.Should().Be("申请已提交，等待子女审批");
        result.FamilyName.Should().Be("加入测试家庭");

        // 验证：数据库中创建了 Pending 状态的成员记录
        var pendingMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == joiner.Id);
        pendingMember.Should().NotBeNull();
        pendingMember!.Status.Should().Be(FamilyMemberStatus.Pending);
        pendingMember.Relation.Should().Be("父亲");

        // 验证：通知已发送给子女
        _mockNotification.Verify(
            n => n.SendToUsersAsync(
                It.IsAny<IEnumerable<Guid>>(),
                "FamilyJoinRequest",
                It.IsAny<object>()),
            Times.Once);
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
            .WithMessage(ErrorMessages.Family.InvalidInviteCode);
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
            Relation = "创建者",
            Status = FamilyMemberStatus.Approved
        });
        await _context.SaveChangesAsync();

        var request = new JoinFamilyRequest
        {
            InviteCode = "111111",
            Relation = "朋友"
        };

        // 执行并验证：已在家庭中的用户不能重复申请
        var act = async () => await _service.JoinFamilyByCodeAsync(creator.Id, request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage(ErrorMessages.Family.AlreadyAppliedOrJoined);
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
            Relation = "创建者",
            Status = FamilyMemberStatus.Approved
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
                Relation = "创建者",
                Status = FamilyMemberStatus.Approved
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = member.Id,
                Role = UserRole.Elder,
                Relation = "父亲",
                Status = FamilyMemberStatus.Approved
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
            Relation = "创建者",
            Status = FamilyMemberStatus.Approved
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
            Relation = "创建者",
            Status = FamilyMemberStatus.Approved
        });
        await _context.SaveChangesAsync();

        // 执行并验证：非家庭成员刷新邀请码应抛出权限异常
        var act = async () => await _service.RefreshInviteCodeAsync(family.Id, stranger.Id);
        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage(ErrorMessages.Family.NotFamilyMember);
    }

    [Fact]
    public async Task ApproveMemberAsync_ShouldApprove()
    {
        // 准备：创建家庭、子女操作者和待审批成员
        var operator_ = await CreateUserAsync("13700009001", "审批操作者", UserRole.Child);
        var applicant = await CreateUserAsync("13700009002", "申请人", UserRole.Elder);

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "审批测试家庭",
            CreatorId = operator_.Id,
            InviteCode = "666666",
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
                Relation = "创建者",
                Status = FamilyMemberStatus.Approved
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = applicant.Id,
                Role = UserRole.Elder,
                Relation = "爷爷",
                Status = FamilyMemberStatus.Pending
            }
        );
        await _context.SaveChangesAsync();

        // 执行：审批通过
        await _service.ApproveMemberAsync(family.Id, applicant.Id, operator_.Id);

        // 验证：成员状态变为 Approved
        var member = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == applicant.Id);
        member.Should().NotBeNull();
        member!.Status.Should().Be(FamilyMemberStatus.Approved);

        // 验证：通知已发送给申请人
        _mockNotification.Verify(
            n => n.SendToUserAsync(
                applicant.Id,
                "FamilyJoinApproved",
                It.IsAny<object>()),
            Times.Once);
    }

    [Fact]
    public async Task RejectMemberAsync_ShouldRemoveRecord()
    {
        // 准备：创建家庭、子女操作者和待审批成员
        var operator_ = await CreateUserAsync("13700010001", "拒绝操作者", UserRole.Child);
        var applicant = await CreateUserAsync("13700010002", "被拒绝申请人", UserRole.Elder);

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "拒绝测试家庭",
            CreatorId = operator_.Id,
            InviteCode = "777777",
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = operator_.Id,
            Role = UserRole.Child,
            Relation = "创建者",
            Status = FamilyMemberStatus.Approved
        });
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = applicant.Id,
            Role = UserRole.Elder,
            Relation = "奶奶",
            Status = FamilyMemberStatus.Pending
        });
        await _context.SaveChangesAsync();

        // 执行：拒绝申请
        await _service.RejectMemberAsync(family.Id, applicant.Id, operator_.Id);

        // 验证：申请记录已删除
        var member = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == applicant.Id);
        member.Should().BeNull();

        // 验证：通知已发送给申请人
        _mockNotification.Verify(
            n => n.SendToUserAsync(
                applicant.Id,
                "FamilyJoinRejected",
                It.IsAny<object>()),
            Times.Once);
    }

    [Fact]
    public async Task GetPendingMembersAsync_ShouldReturnOnlyPending()
    {
        // 准备：创建家庭，包含不同状态的成员
        var operator_ = await CreateUserAsync("13700011001", "查询操作者", UserRole.Child);
        var pendingUser = await CreateUserAsync("13700011002", "待审批用户", UserRole.Elder);
        var approvedUser = await CreateUserAsync("13700011003", "已通过用户", UserRole.Elder);

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "查询测试家庭",
            CreatorId = operator_.Id,
            InviteCode = "999999",
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
                Relation = "创建者",
                Status = FamilyMemberStatus.Approved
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = pendingUser.Id,
                Role = UserRole.Elder,
                Relation = "爷爷",
                Status = FamilyMemberStatus.Pending
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = approvedUser.Id,
                Role = UserRole.Elder,
                Relation = "奶奶",
                Status = FamilyMemberStatus.Approved
            }
        );
        await _context.SaveChangesAsync();

        // 执行：查询待审批成员
        var result = await _service.GetPendingMembersAsync(family.Id, operator_.Id);

        // 验证：只返回待审批成员
        result.Should().HaveCount(1);
        result[0].UserId.Should().Be(pendingUser.Id);
        result[0].Status.Should().Be(FamilyMemberStatus.Pending);
    }

    [Fact]
    public async Task GetMyFamilyAsync_ShouldOnlyReturnApprovedMembers()
    {
        // 准备：创建家庭，包含已通过和待审批成员
        var creator = await CreateUserAsync("13700012001", "创建者", UserRole.Child);
        var approvedUser = await CreateUserAsync("13700012002", "已通过用户", UserRole.Elder);
        var pendingUser = await CreateUserAsync("13700012003", "待审批用户", UserRole.Elder);

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "筛选测试家庭",
            CreatorId = creator.Id,
            InviteCode = "123456",
            CreatedAt = DateTime.UtcNow
        };
        _context.Families.Add(family);
        _context.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = creator.Id,
                Role = UserRole.Child,
                Relation = "创建者",
                Status = FamilyMemberStatus.Approved
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = approvedUser.Id,
                Role = UserRole.Elder,
                Relation = "爷爷",
                Status = FamilyMemberStatus.Approved
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = pendingUser.Id,
                Role = UserRole.Elder,
                Relation = "奶奶",
                Status = FamilyMemberStatus.Pending
            }
        );
        await _context.SaveChangesAsync();

        // 执行：查询家庭信息（使用已通过用户的身份）
        var result = await _service.GetMyFamilyAsync(approvedUser.Id);

        // 验证：只返回已通过审批的成员
        result.Should().NotBeNull();
        result!.Members.Should().HaveCount(2); // 创建者 + 已通过用户
        result.Members.Should().NotContain(m => m.UserId == pendingUser.Id);
    }
}
