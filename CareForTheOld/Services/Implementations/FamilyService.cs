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
    private static readonly Random _random = new();

    public FamilyService(AppDbContext context) => _context = context;

    /// <summary>
    /// 生成 6 位数字邀请码
    /// </summary>
    private static string GenerateInviteCode()
    {
        return _random.Next(100000, 999999).ToString();
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
        var creator = await _context.Users.FindAsync(creatorId)
            ?? throw new KeyNotFoundException("用户不存在");

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = request.FamilyName,
            CreatorId = creatorId,
            InviteCode = GenerateInviteCode(),
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
        await _context.SaveChangesAsync();

        return await GetFamilyResponse(family.Id);
    }

    public async Task<FamilyResponse> AddMemberAsync(Guid familyId, Guid operatorId, AddFamilyMemberRequest request)
    {
        await EnsureMemberAsync(familyId, operatorId);

        var user = await _context.Users.FirstOrDefaultAsync(u => u.PhoneNumber == request.PhoneNumber)
            ?? throw new KeyNotFoundException($"未找到手机号为 {request.PhoneNumber} 的用户");

        if (await _context.FamilyMembers.AnyAsync(fm => fm.FamilyId == familyId && fm.UserId == user.Id))
            throw new ArgumentException("该用户已在家庭组中");

        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = user.Id,
            Role = request.Role,
            Relation = request.Relation,
        });

        await _context.SaveChangesAsync();
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

        // 添加用户到家庭
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = userId,
            Role = user.Role,
            Relation = request.Relation,
        });

        await _context.SaveChangesAsync();
        return await GetFamilyResponse(family.Id);
    }

    /// <summary>
    /// 刷新邀请码
    /// </summary>
    public async Task<FamilyResponse> RefreshInviteCodeAsync(Guid familyId, Guid operatorId)
    {
        await EnsureMemberAsync(familyId, operatorId);

        var family = await _context.Families.FindAsync(familyId)
            ?? throw new KeyNotFoundException("家庭组不存在");

        family.InviteCode = GenerateInviteCode();
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
        await EnsureMemberAsync(familyId, operatorId);

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
}