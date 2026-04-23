using System.Security.Cryptography;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

public class FamilyService : IFamilyService
{
    private readonly AppDbContext _context;

    /// <summary>邀请码有效期（7天）</summary>
    private static readonly TimeSpan _inviteCodeExpiration = TimeSpan.FromDays(7);

    public FamilyService(AppDbContext context) => _context = context;

    /// <summary>
    /// 使用加密随机数生成器生成 6 位数字邀请码，防止可预测攻击
    /// </summary>
    private static string GenerateInviteCode()
    {
        return RandomNumberGenerator.GetInt32(100000, 999999).ToString();
    }

    /// <summary>
    /// 获取用户所属的家庭信息
    /// </summary>
    public async Task<FamilyResponse?> GetMyFamilyAsync(Guid userId)
    {
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == userId);

        if (familyMember == null)
            return null;

        return await GetFamilyResponse(familyMember.FamilyId);
    }

    public async Task<FamilyResponse> CreateFamilyAsync(Guid creatorId, CreateFamilyRequest request)
    {
        // 检查用户是否已加入其他家庭
        if (await _context.FamilyMembers.AnyAsync(fm => fm.UserId == creatorId))
            throw new ArgumentException("您已加入家庭组，不能重复创建");

        var creator = await _context.Users.FindAsync(creatorId)
            ?? throw new KeyNotFoundException("用户不存在");

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = request.FamilyName,
            CreatorId = creatorId,
            InviteCode = GenerateInviteCode(),
            InviteCodeExpiresAt = DateTime.UtcNow.Add(_inviteCodeExpiration),
            CreatedAt = DateTime.UtcNow
        };

        // 创建者自动加入家庭组
        family.Members.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            UserId = creatorId,
            Role = creator.Role,
            Relation = "创建者"
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
    /// 通过邀请码加入家庭
    /// </summary>
    public async Task<FamilyResponse> JoinFamilyByCodeAsync(Guid userId, JoinFamilyRequest request)
    {
        // 检查用户是否已在某个家庭中
        if (await _context.FamilyMembers.AnyAsync(fm => fm.UserId == userId))
            throw new ArgumentException("您已加入家庭组，不能重复加入");

        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("用户不存在");

        // 根据邀请码查找家庭
        var family = await _context.Families
            .FirstOrDefaultAsync(f => f.InviteCode == request.InviteCode)
            ?? throw new KeyNotFoundException("邀请码无效，请检查后重试");

        // 验证邀请码是否过期
        if (family.InviteCodeExpiresAt.HasValue && family.InviteCodeExpiresAt.Value < DateTime.UtcNow)
            throw new ArgumentException("邀请码已过期，请联系家庭创建者获取新邀请码");

        // 添加用户到家庭
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = userId,
            Role = user.Role,
            Relation = request.Relation,
        });

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException("您已加入家庭组，不能重复加入");
        }

        return await GetFamilyResponse(family.Id);
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
        return await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.FamilyId == familyId)
            .Select(fm => new FamilyMemberResponse
            {
                UserId = fm.UserId,
                RealName = fm.User.RealName,
                Role = fm.Role,
                Relation = fm.Relation,
                AvatarUrl = fm.User.AvatarUrl,
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
        if (!await _context.FamilyMembers.AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == userId))
            throw new UnauthorizedAccessException("您不是该家庭成员");
    }

    /// <inheritdoc />
    public async Task EnsureFamilyMemberAsync(Guid elderId, Guid operatorId)
    {
        // 老人本人可以操作
        if (elderId == operatorId) return;

        // 先查操作者所在家庭，再验证老人是否同家庭
        var operatorFamilyId = await _context.FamilyMembers
            .Where(fm => fm.UserId == operatorId)
            .Select(fm => fm.FamilyId)
            .FirstOrDefaultAsync();

        if (operatorFamilyId == Guid.Empty)
            throw new UnauthorizedAccessException("您不是该老人的家庭成员，无权操作");

        var isInSameFamily = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == elderId && fm.FamilyId == operatorFamilyId);

        if (!isInSameFamily)
            throw new UnauthorizedAccessException("您不是该老人的家庭成员，无权操作");
    }

    private async Task<FamilyResponse> GetFamilyResponse(Guid familyId)
    {
        var family = await _context.Families
            .Include(f => f.Members).ThenInclude(fm => fm.User)
            .FirstAsync(f => f.Id == familyId);

        return new FamilyResponse
        {
            Id = family.Id,
            FamilyName = family.FamilyName,
            InviteCode = family.InviteCode,
            InviteCodeExpiresAt = family.InviteCodeExpiresAt,
            Members = family.Members.Select(fm => new FamilyMemberResponse
            {
                UserId = fm.UserId,
                RealName = fm.User.RealName,
                Role = fm.Role,
                Relation = fm.Relation,
                AvatarUrl = fm.User.AvatarUrl,
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