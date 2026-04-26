using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 家庭组管理服务
/// 提供家庭组创建、成员管理、邀请码、审批流程等功能
/// </summary>
public class FamilyService : IFamilyService
{
    private readonly AppDbContext _context;
    private readonly INotificationService _notificationService;

    /// <summary>邀请码有效期</summary>
    private static readonly TimeSpan _inviteCodeExpiration = TimeSpan.FromDays(AppConstants.InviteCode.ExpirationDays);

    public FamilyService(AppDbContext context, INotificationService notificationService)
    {
        _context = context;
        _notificationService = notificationService;
    }

    /// <summary>
    /// 使用加密随机数生成器生成 6 位数字邀请码，防止可预测攻击
    /// </summary>
    private static string GenerateInviteCode() => InviteCodeHelper.Generate();

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

    /// <summary>
    /// 创建家庭组（仅子女可创建，创建者自动加入）
    /// </summary>
    public async Task<FamilyResponse> CreateFamilyAsync(Guid creatorId, CreateFamilyRequest request)
    {
        // 验证创建者角色：只有子女才能创建家庭组
        var creator = await _context.Users.FindAsync(creatorId)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);
        if (creator.Role != UserRole.Child)
            throw new UnauthorizedAccessException(ErrorMessages.Family.OnlyChildCanCreate);

        // 检查用户是否已加入其他家庭
        if (await _context.FamilyMembers.AnyAsync(fm => fm.UserId == creatorId))
            throw new ArgumentException(ErrorMessages.Family.AlreadyInFamily);

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
            Relation = NotificationMessages.Family.CreatorRole,
            Status = FamilyMemberStatus.Approved
        });

        _context.Families.Add(family);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.Family.AlreadyInFamily);
        }

        return await GetFamilyResponse(family.Id);
    }

    /// <summary>
    /// 直接添加家庭成员（子女操作，被添加者默认通过审批）
    /// </summary>
    public async Task<FamilyResponse> AddMemberAsync(Guid familyId, Guid operatorId, AddFamilyMemberRequest request)
    {
        await EnsureMemberAsync(familyId, operatorId);

        var user = await _context.Users.FirstOrDefaultAsync(u => u.PhoneNumber == request.PhoneNumber);
        // 使用模糊错误消息，防止用户枚举攻击
        if (user == null)
            throw new KeyNotFoundException(ErrorMessages.Family.CannotAddUser);

        if (await _context.FamilyMembers.AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == user.Id))
            throw new ArgumentException(ErrorMessages.Family.UserAlreadyInFamily);

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
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.Family.UserAlreadyInOtherFamily);
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
            throw new ArgumentException(ErrorMessages.Family.AlreadyAppliedOrJoined);

        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 根据邀请码查找家庭
        var family = await _context.Families
            .FirstOrDefaultAsync(f => f.InviteCode == request.InviteCode)
            ?? throw new KeyNotFoundException(ErrorMessages.Family.InvalidInviteCode);

        // 验证邀请码是否过期
        if (family.InviteCodeExpiresAt.HasValue && family.InviteCodeExpiresAt.Value < DateTime.UtcNow)
            throw new ArgumentException(ErrorMessages.Family.InviteCodeExpired);

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
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.Family.AlreadyAppliedOrJoined);
        }

        // 通知家庭中所有子女角色成员审批
        var childMembers = await _context.FamilyMembers
            .Where(fm => fm.FamilyId == family.Id && fm.Role == UserRole.Child && fm.Status == FamilyMemberStatus.Approved)
            .Select(fm => fm.UserId)
            .ToListAsync();

        if (childMembers.Any())
        {
            await _notificationService.SendToUsersAsync(childMembers, AppConstants.NotificationTypes.FamilyJoinRequest, new
            {
                Title = NotificationMessages.Family.JoinRequestTitle,
                Content = string.Format(NotificationMessages.Family.JoinRequestContentTemplate, user.RealName, request.Relation, family.FamilyName),
                FamilyId = family.Id,
                FamilyName = family.FamilyName,
                ApplicantId = userId,
                ApplicantName = user.RealName,
                Relation = request.Relation
            });
        }

        return new JoinFamilyResponse
        {
            Message = NotificationMessages.Family.JoinAppliedMessage,
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
            ?? throw new UnauthorizedAccessException(ErrorMessages.Family.NotFamilyMember);

        if (operatorMember.Role != UserRole.Child)
            throw new UnauthorizedAccessException(ErrorMessages.Family.OnlyChildCanApprove);

        var member = await _context.FamilyMembers
            .Include(fm => fm.User)
            .FirstOrDefaultAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId && fm.Status == FamilyMemberStatus.Pending)
            ?? throw new KeyNotFoundException(ErrorMessages.Family.PendingMemberNotFound);

        member.Status = FamilyMemberStatus.Approved;
        await _context.SaveChangesAsync();

        // 通知申请人审批已通过
        var family = await _context.Families.FindAsync(familyId);
        var operatorUser = await _context.Users.FindAsync(operatorId);

        await _notificationService.SendToUserAsync(memberId, AppConstants.NotificationTypes.FamilyJoinApproved, new
        {
            Title = NotificationMessages.Family.JoinApprovedTitle,
            Content = string.Format(NotificationMessages.Family.JoinApprovedContentTemplate,
                operatorUser?.RealName ?? NotificationMessages.Family.DefaultOperatorName,
                family?.FamilyName ?? NotificationMessages.Family.DefaultFamilyName),
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
            ?? throw new UnauthorizedAccessException(ErrorMessages.Family.NotFamilyMember);

        if (operatorMember.Role != UserRole.Child)
            throw new UnauthorizedAccessException(ErrorMessages.Family.OnlyChildCanApprove);

        var member = await _context.FamilyMembers
            .Include(fm => fm.User)
            .FirstOrDefaultAsync(fm => fm.FamilyId == familyId && fm.UserId == memberId && fm.Status == FamilyMemberStatus.Pending)
            ?? throw new KeyNotFoundException(ErrorMessages.Family.PendingMemberNotFound);

        // 删除申请记录（而非保留 Rejected 状态，避免唯一约束冲突导致无法再次申请）
        _context.FamilyMembers.Remove(member);
        await _context.SaveChangesAsync();

        // 通知申请人被拒绝
        var family = await _context.Families.FindAsync(familyId);

        await _notificationService.SendToUserAsync(memberId, AppConstants.NotificationTypes.FamilyJoinRejected, new
        {
            Title = NotificationMessages.Family.JoinRejectedTitle,
            Content = string.Format(NotificationMessages.Family.JoinRejectedContentTemplate, family?.FamilyName ?? NotificationMessages.Family.DefaultFamilyName),
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
            ?? throw new KeyNotFoundException(ErrorMessages.Family.FamilyNotFound);

        if (family.CreatorId != operatorId)
            throw new UnauthorizedAccessException(string.Format(ErrorMessages.Family.OnlyCreatorCanOperate, "刷新邀请码"));

        family.InviteCode = GenerateInviteCode();
        family.InviteCodeExpiresAt = DateTime.UtcNow.Add(_inviteCodeExpiration);
        await _context.SaveChangesAsync();

        return await GetFamilyResponse(familyId);
    }

    /// <summary>
    /// 获取家庭成员列表（仅返回已通过审批的成员）
    /// </summary>
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

    /// <summary>
    /// 移除家庭成员（仅家庭创建者可操作，不可移除自己）
    /// </summary>
    public async Task RemoveMemberAsync(Guid familyId, Guid userId, Guid operatorId)
    {
        // 验证操作者是家庭创建者
        var family = await _context.Families.FindAsync(familyId)
            ?? throw new KeyNotFoundException(ErrorMessages.Family.FamilyNotFound);

        if (family.CreatorId != operatorId)
            throw new UnauthorizedAccessException(string.Format(ErrorMessages.Family.OnlyCreatorCanOperate, "移除成员"));

        // 不能移除创建者本人
        if (userId == family.CreatorId)
            throw new ArgumentException(ErrorMessages.Family.CannotRemoveCreator);

        var member = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.FamilyId == familyId && fm.UserId == userId)
            ?? throw new KeyNotFoundException(ErrorMessages.Family.UserNotInFamily);

        _context.FamilyMembers.Remove(member);
        await _context.SaveChangesAsync();
    }

    private async Task EnsureMemberAsync(Guid familyId, Guid userId)
    {
        if (!await _context.FamilyMembers.AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == userId && fm.Status == FamilyMemberStatus.Approved))
            throw new UnauthorizedAccessException(ErrorMessages.Family.NotFamilyMember);
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
            throw new UnauthorizedAccessException(ErrorMessages.Family.NotElderFamilyMember);

        var isInSameFamily = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == elderId && fm.FamilyId == operatorFamilyId && fm.Status == FamilyMemberStatus.Approved);

        if (!isInSameFamily)
            throw new UnauthorizedAccessException(ErrorMessages.Family.NotElderFamilyMember);
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
}
