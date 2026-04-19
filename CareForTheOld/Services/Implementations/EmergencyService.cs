using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 紧急呼叫服务实现
/// </summary>
public class EmergencyService : IEmergencyService
{
    private readonly AppDbContext _context;

    public EmergencyService(AppDbContext context) => _context = context;

    /// <summary>
    /// 老人发起紧急呼叫
    /// </summary>
    public async Task<EmergencyCallResponse> CreateCallAsync(Guid elderId)
    {
        // 获取老人的家庭信息
        var familyMember = await _context.FamilyMembers
            .Include(fm => fm.User)
            .FirstOrDefaultAsync(fm => fm.UserId == elderId);

        if (familyMember == null)
            throw new InvalidOperationException("您不在任何家庭组中，无法发起紧急呼叫");

        // 创建紧急呼叫记录
        var call = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elderId,
            FamilyId = familyMember.FamilyId,
            CalledAt = DateTime.UtcNow,
            Status = EmergencyStatus.Pending,
        };

        _context.EmergencyCalls.Add(call);
        await _context.SaveChangesAsync();

        // 返回响应
        return new EmergencyCallResponse
        {
            Id = call.Id,
            ElderId = call.ElderId,
            ElderName = familyMember.User.RealName,
            ElderPhoneNumber = familyMember.User.PhoneNumber,
            FamilyId = call.FamilyId,
            CalledAt = call.CalledAt,
            Status = call.Status,
        };
    }

    /// <summary>
    /// 获取未处理的紧急呼叫（子女端）
    /// </summary>
    public async Task<List<EmergencyCallResponse>> GetUnreadCallsAsync(Guid userId)
    {
        // 获取子女的家庭信息
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == userId);

        if (familyMember == null)
            return [];

        // 获取该家庭中未处理的紧急呼叫
        var calls = await _context.EmergencyCalls
            .Include(c => c.Elder)
            .Where(c => c.FamilyId == familyMember.FamilyId && c.Status == EmergencyStatus.Pending)
            .OrderByDescending(c => c.CalledAt)
            .ToListAsync();

        return calls.Select(c => new EmergencyCallResponse
        {
            Id = c.Id,
            ElderId = c.ElderId,
            ElderName = c.Elder.RealName,
            ElderPhoneNumber = c.Elder.PhoneNumber,
            FamilyId = c.FamilyId,
            CalledAt = c.CalledAt,
            Status = c.Status,
        }).ToList();
    }

    /// <summary>
    /// 获取历史呼叫记录
    /// </summary>
    public async Task<List<EmergencyCallResponse>> GetHistoryAsync(Guid userId, int skip = 0, int limit = 20)
    {
        // 获取用户的家庭信息
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == userId);

        if (familyMember == null)
            return [];

        // 获取该家庭的所有紧急呼叫记录
        var calls = await _context.EmergencyCalls
            .Include(c => c.Elder)
            .Where(c => c.FamilyId == familyMember.FamilyId)
            .OrderByDescending(c => c.CalledAt)
            .Skip(skip)
            .Take(limit)
            .ToListAsync();

        return calls.Select(c => new EmergencyCallResponse
        {
            Id = c.Id,
            ElderId = c.ElderId,
            ElderName = c.Elder.RealName,
            ElderPhoneNumber = c.Elder.PhoneNumber,
            FamilyId = c.FamilyId,
            CalledAt = c.CalledAt,
            Status = c.Status,
            RespondedBy = c.RespondedBy,
            RespondedByRealName = c.RespondedByRealName,
            RespondedAt = c.RespondedAt,
        }).ToList();
    }

    /// <summary>
    /// 子女标记已处理
    /// </summary>
    public async Task<EmergencyCallResponse> RespondCallAsync(Guid callId, Guid userId)
    {
        // 获取用户信息
        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("用户不存在");

        // 获取呼叫记录
        var call = await _context.EmergencyCalls
            .AsTracking()
            .Include(c => c.Elder)
            .FirstOrDefaultAsync(c => c.Id == callId);

        if (call == null)
            throw new KeyNotFoundException("紧急呼叫记录不存在");

        if (call.Status == EmergencyStatus.Responded)
            throw new InvalidOperationException("该呼叫已被处理");

        // 验证用户是否是该家庭成员
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == userId && fm.FamilyId == call.FamilyId);

        if (!isMember)
            throw new UnauthorizedAccessException("您不是该家庭成员，无法处理此呼叫");

        // 更新呼叫状态
        call.Status = EmergencyStatus.Responded;
        call.RespondedBy = userId;
        call.RespondedByRealName = user.RealName;
        call.RespondedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return new EmergencyCallResponse
        {
            Id = call.Id,
            ElderId = call.ElderId,
            ElderName = call.Elder.RealName,
            ElderPhoneNumber = call.Elder.PhoneNumber,
            FamilyId = call.FamilyId,
            CalledAt = call.CalledAt,
            Status = call.Status,
            RespondedBy = call.RespondedBy,
            RespondedByRealName = call.RespondedByRealName,
            RespondedAt = call.RespondedAt,
        };
    }
}