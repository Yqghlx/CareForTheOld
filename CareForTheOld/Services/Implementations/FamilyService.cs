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

    public FamilyService(AppDbContext context) => _context = context;

    public async Task<FamilyResponse> CreateFamilyAsync(Guid creatorId, CreateFamilyRequest request)
    {
        var creator = await _context.Users.FindAsync(creatorId)
            ?? throw new KeyNotFoundException("用户不存在");

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = request.FamilyName,
            CreatorId = creatorId,
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