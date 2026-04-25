using System.Security.Cryptography;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

public class FamilyService : IFamilyService
{
    private readonly AppDbContext _context;
    private readonly INotificationService _notificationService;

    /// <summary>邀请码有效期（7天）</summary>
    private static readonly TimeSpan _inviteCodeExpiration = TimeSpan.FromDays(7);

    public FamilyService(AppDbContext context, INotificationService notificationService)
    {
        _context = context;
        _notificationService = notificationService;
    }

    /// <summary>
    /// 使用加密随机数生成器生成 6 位数字邀请码，防止可预测攻击
    /// </summary>
    private static string GenerateInviteCode()
    {
        return RandomNumberGenerator.GetInt32(100000, 999999).ToString();
    }

    /// <summary>
    /// 获取用户所属的家庭信息（仅返回已通过审批的成员）
    /// </summary>
    public async Task<FamilyResponse?> GetMyFamilyAsync(Guid userId)
    {
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == userId && fm.Status == FamilyMemberStatus.Approved);

        if (familyMember == null)
            return null;

        return await GetFamilyResponse(familyMember.FamilyId);
    }

    public async Task<FamilyResponse> CreateFamilyAsync(Guid creatorId, CreateFamilyRequest request)
    {
        // 验证创建者角色：只有子女才能创建家庭组
        var creator = await _context.Users.FindAsync(creatorId)
            ?? throw new KeyNotFoundException("用户不存在");
        if (creator.Role != UserRole.Child)
            throw new UnauthorizedAccessException("只有子女才能创建家庭组");

        // 检查用户是否已加入其他家庭
        if (await _context.FamilyMembers.AnyAsync(fm => fm.UserId == creatorId))
            throw new ArgumentException("您已加入家庭组，不能重复创建");

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = request.FamilyName,
            CreatorId = creatorId,
            InviteCode = GenerateInviteCode(),
            InviteCodeExpiresAt = DateTime.UtcNow.Add(_inviteCodeExpiration),
            CreatedAt = DateTime.UtcNow
        };

        // 创建者自动加入家庭组（状态为 Approved）
        family.Members.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            UserId = creatorId,
            Role = creator.Role,
            Relation = "创建者",
            Status = FamilyMemberStatus.Approved
        });

        _context.Families.Add(family);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException("您已加入家庭组，不能重复创建");
        }

        return await GetFamilyResponse(family.Id);
    }

    public async Task<FamilyResponse> AddMemberAsync(Guid familyId, Guid operatorId, AddFamilyMemberRequest request)
    {
        await EnsureMemberAsync(familyId, operatorId);

        var user = await _context.Users.FirstOrDefaultAsync(u => u.PhoneNumber == request.PhoneNumber);
        // 使用模糊错误消息，防止用户枚举攻击
        if (user == null)
            throw new KeyNotFoundException("无法添加该用户，请确认手机号正确且用户已注册");

        if (await _context.FamilyMembers.AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == user.Id))
            throw new ArgumentException("该用户已在家庭组中");

        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = user.Id,
            Role = user.Role, // 使用用户实际角色，防止客户端伪造
            Relation = request.Relation,
            Status = FamilyMemberStatus.Approved // 子女直接添加的成员默认通过
        });

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException("该用户已加入其他家庭组");
        }

        return await GetFamilyResponse(familyId);
    }

    /// <summary>
    /// 通过邀请码申请加入家庭（改为申请模式，需子女审批）
    /// </summary>
    public async Task<JoinFamilyResponse> JoinFamilyByCodeAsync(Guid userId, JoinFamilyRequest request)
    {
        // 检查用户是否已在某个家庭中（含待审批记录）
        if (await _context.FamilyMembers.AnyAsync(fm => fm.UserId == userId))
            throw new ArgumentException("您已提交加入申请或已加入家庭组，不能重复申请");

        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("用户不存在");

        // 根据邀请码查找家庭
        var family = await _context.Families
            .FirstOrDefaultAsync(f => f.InviteCode == request.InviteCode)
            ?? throw new KeyNotFoundException("邀请码无效，请检查后重试");

        // 验证邀请码是否过期
        if (family.InviteCodeExpiresAt.HasValue && family.InviteCodeExpiresAt.Value < DateTime.UtcNow)
            throw new ArgumentException("邀请码已过期，请联系家庭创建者获取新邀请码");

        // 创建待审批成员记录
        var member = new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = userId,
            Role = user.Role,
            Relation = request.Relation,
            Status = FamilyMemberStatus.Pending
        };

        _context.FamilyMembers.Add(member);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException("您已提交加入申请或已加入家庭组，不能重复申请");
        }

        // 通知家庭中所有子女角色成员审批
        var childMembers = await _context.FamilyMembers
            .Where(fm => fm.FamilyId == family.Id && fm.Role == UserRole.Child && fm.Status == FamilyMemberStatus.Approved)
            .Select(fm => fm.UserId)
            .ToListAsync();

        if (childMembers.Count > 0)
        {
            await _notificationService.SendToUsersAsync(childMembers, "FamilyJoinRequest", new
            {
                Title = "家庭加入申请",
                Content = $"{user.RealName}（{request.Relation}）申请加入{family.FamilyName}，请审批",
                FamilyId = family.Id,
                FamilyName = family.FamilyName,
                ApplicantId = userId,
                ApplicantName = user.RealName,
                Relation = request.Relation
            });
        }

        return new JoinFamilyResponse
        {
            Message = "申请已提交，等待子女审批",
            FamilyName = family.FamilyName,
            Status = FamilyMemberStatus.Pending
        };
    }

    /// <summary>
    /// 获取待审批成员列表（仅子女可查看）
    /// </summary>
    public async Task<List<FamilyMemberResponse>> GetPendingMembersAsync(Guid familyId, Guid operatorId)
    {
        await EnsureMemberAsync(familyId, operatorId);

        return await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.FamilyId == familyId && fm.Status == FamilyMemberStatus.Pending)
            .Select(fm => new FamilyMemberResponse
            {
                UserId = fm.UserId,
                RealName = fm.User.RealName,
                Role = fm.Role,
                Relation = fm.Relation,
                AvatarUrl = fm.User.AvatarUrl,
                Status = fm.Status
            })
            .ToListAsync();
    }

    /// <summary>
    /// 审批通过成员加入（仅子女可操作）
    /// </summary>
    public async Task ApproveMemberAsync(Guid familyId, Guid memberId, Guid operatorId)
    {
        await EnsureMemberAsync(familyId, operatorId);

        // 验证操作者是子女角色
        var operatorMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.FamilyId == familyId && fm.UserId == operatorId)
            ?? throw new UnauthorizedAccessException("您不是该家庭成员");

        if (operatorMember.Role != UserRole.Child)
            throw new UnauthorizedAccessException("仅子女可以审批成员");

        var member = await _context.FamilyMembers
            .Include(fm => fm.User)
            .FirstOrDefaultAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId && fm.Status == FamilyMemberStatus.Pending)
            ?? throw new KeyNotFoundException("未找到该待审批成员");

        member.Status = FamilyMemberStatus.Approved;
        await _context.SaveChangesAsync();

        // 通知申请人审批已通过
        var family = await _context.Families.FindAsync(familyId);
        var operatorUser = await _context.Users.FindAsync(operatorId);

        await _notificationService.SendToUserAsync(memberId, "FamilyJoinApproved", new
        {
            Title = "加入申请已通过",
            Content = $"{operatorUser?.RealName ?? "管理员"}已同意您加入{family?.FamilyName ?? "家庭组"}",
            FamilyId = familyId,
            FamilyName = family?.FamilyName ?? ""
        });
    }

    /// <summary>
    /// 拒绝成员加入申请（仅子女可操作）
    /// </summary>
    public async Task RejectMemberAsync(Guid familyId, Guid memberId, Guid operatorId)
    {
        await EnsureMemberAsync(familyId, operatorId);

        // 验证操作者是子女角色
        var operatorMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.FamilyId == familyId && fm.UserId == operatorId)
            ?? throw new UnauthorizedAccessException("您不是该家庭成员");

        if (operatorMember.Role != UserRole.Child)
            throw new UnauthorizedAccessException("仅子女可以审批成员");

        var member = await _context.FamilyMembers
            .Include(fm => fm.User)
            .FirstOrDefaultAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId && fm.Status == FamilyMemberStatus.Pending)
            ?? throw new KeyNotFoundException("未找到该待审批成员");

        // 删除申请记录（而非保留 Rejected 状态，避免唯一约束冲突导致无法再次申请）
        _context.FamilyMembers.Remove(member);
        await _context.SaveChangesAsync();

        // 通知申请人被拒绝
        var family = await _context.Families.FindAsync(familyId);

        await _notificationService.SendToUserAsync(memberId, "FamilyJoinRejected", new
        {
            Title = "加入申请被拒绝",
            Content = $"{family?.FamilyName ?? "家庭组"}的管理员拒绝了您的加入申请",
            FamilyId = familyId,
            FamilyName = family?.FamilyName ?? ""
        });
    }

    /// <summary>
    /// 刷新邀请码（仅家庭创建者可操作）
    /// </summary>
    public async Task<FamilyResponse> RefreshInviteCodeAsync(Guid familyId, Guid operatorId)
    {
        await EnsureMemberAsync(familyId, operatorId);

        var family = await _context.Families.AsTracking().FirstOrDefaultAsync(f => f.Id == familyId)
            ?? throw new KeyNotFoundException("家庭组不存在");

        if (family.CreatorId != operatorId)
            throw new UnauthorizedAccessException("仅家庭创建者可以刷新邀请码");

        family.InviteCode = GenerateInviteCode();
        family.InviteCodeExpiresAt = DateTime.UtcNow.Add(_inviteCodeExpiration);
        await _context.SaveChangesAsync();

        return await GetFamilyResponse(familyId);
    }

    public async Task<List<FamilyMemberResponse>> GetMembersAsync(Guid familyId)
    {
        // 只返回已通过审批的成员
        return await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.FamilyId == familyId && fm.Status == FamilyMemberStatus.Approved)
            .Select(fm => new FamilyMemberResponse
            {
                UserId = fm.UserId,
                RealName = fm.User.RealName,
                Role = fm.Role,
                Relation = fm.Relation,
                AvatarUrl = fm.User.AvatarUrl,
                Status = fm.Status
            })
            .ToListAsync();
    }

    public async Task RemoveMemberAsync(Guid familyId, Guid userId, Guid operatorId)
    {
        // 验证操作者是家庭创建者
        var family = await _context.Families.FindAsync(familyId)
            ?? throw new KeyNotFoundException("家庭组不存在");

        if (family.CreatorId != operatorId)
            throw new UnauthorizedAccessException("仅家庭创建者可以移除成员");

        // 不能移除创建者本人
        if (userId == family.CreatorId)
            throw new ArgumentException("不能移除家庭创建者");

        var member = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.FamilyId == familyId && fm.UserId == userId)
            ?? throw new KeyNotFoundException("该用户不在家庭组中");

        _context.FamilyMembers.Remove(member);
        await _context.SaveChangesAsync();
    }

    private async Task EnsureMemberAsync(Guid familyId, Guid userId)
    {
        if (!await _context.FamilyMembers.AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == userId && fm.Status == FamilyMemberStatus.Approved))
            throw new UnauthorizedAccessException("您不是该家庭成员");
    }

    /// <inheritdoc />
    public async Task EnsureFamilyMemberAsync(Guid elderId, Guid operatorId)
    {
        // 老人本人可以操作
        if (elderId == operatorId) return;

        // 先查操作者所在家庭，再验证老人是否同家庭
        var operatorFamilyId = await _context.FamilyMembers
            .Where(fm => fm.UserId == operatorId && fm.Status == FamilyMemberStatus.Approved)
            .Select(fm => fm.FamilyId)
            .FirstOrDefaultAsync();

        if (operatorFamilyId == Guid.Empty)
            throw new UnauthorizedAccessException("您不是该老人的家庭成员，无权操作");

        var isInSameFamily = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == elderId && fm.FamilyId == operatorFamilyId && fm.Status == FamilyMemberStatus.Approved);

        if (!isInSameFamily)
            throw new UnauthorizedAccessException("您不是该老人的家庭成员，无权操作");
    }

    private async Task<FamilyResponse> GetFamilyResponse(Guid familyId)
    {
        var family = await _context.Families
            .Include(f => f.Members).ThenInclude(fm => fm.User)
            .FirstAsync(f => f.Id == familyId);

        // 只返回已通过审批的成员
        return new FamilyResponse
        {
            Id = family.Id,
            FamilyName = family.FamilyName,
            InviteCode = family.InviteCode,
            InviteCodeExpiresAt = family.InviteCodeExpiresAt,
            Members = family.Members
                .Where(fm => fm.Status == FamilyMemberStatus.Approved)
                .Select(fm => new FamilyMemberResponse
                {
                    UserId = fm.UserId,
                    RealName = fm.User.RealName,
                    Role = fm.Role,
                    Relation = fm.Relation,
                    AvatarUrl = fm.User.AvatarUrl,
                    Status = fm.Status
                }).ToList()
        };
    }

    /// <summary>
    /// 判断是否为唯一约束冲突异常（兼容 PostgreSQL 和 SQLite）
    /// </summary>
    private static bool IsUniqueConstraintViolation(DbUpdateException ex)
    {
        var inner = ex.InnerException;
        if (inner == null) return false;
        var msg = inner.Message.ToUpperInvariant();
        // PostgreSQL: "23505" unique_violation
        // SQLite: "UNIQUE constraint failed"
        return msg.Contains("UNIQUE") || msg.Contains("23505");
    }
}
