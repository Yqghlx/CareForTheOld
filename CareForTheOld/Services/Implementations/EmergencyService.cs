using CareForTheOld.Common.Extensions;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Hangfire;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 紧急呼叫服务实现
/// </summary>
public class EmergencyService : IEmergencyService
{
    private readonly AppDbContext _context;
    private readonly INotificationService _notificationService;
    private readonly ISmsService _smsService;
    private readonly INeighborHelpService _neighborHelpService;
    private readonly ILogger<EmergencyService> _logger;

    /// <summary>二次提醒延迟时间（默认 3 分钟）</summary>
    private readonly int _followUpDelayMinutes;

    public EmergencyService(
        AppDbContext context,
        INotificationService notificationService,
        ISmsService smsService,
        INeighborHelpService neighborHelpService,
        ILogger<EmergencyService> logger,
        IConfiguration? configuration = null)
    {
        _context = context;
        _notificationService = notificationService;
        _smsService = smsService;
        _neighborHelpService = neighborHelpService;
        _logger = logger;
        _followUpDelayMinutes = configuration?.GetValue("Emergency:FollowUpDelayMinutes", 3) ?? 3;
    }

    /// <summary>
    /// 老人发起紧急呼叫
    /// </summary>
    public async Task<EmergencyCallResponse> CreateCallAsync(Guid elderId, double? latitude = null, double? longitude = null, int? batteryLevel = null)
    {
        // 获取老人的家庭信息
        var familyMember = await _context.FamilyMembers
            .Include(fm => fm.User)
            .FirstOrDefaultAsync(fm => fm.UserId == elderId);

        if (familyMember == null)
            throw new InvalidOperationException("您不在任何家庭组中，无法发起紧急呼叫");

        // 创建紧急呼叫记录（含位置和电量）
        var call = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elderId,
            FamilyId = familyMember.FamilyId,
            CalledAt = DateTime.UtcNow,
            Status = EmergencyStatus.Pending,
            Latitude = latitude,
            Longitude = longitude,
            BatteryLevel = batteryLevel,
        };

        _context.EmergencyCalls.Add(call);
        await _context.SaveChangesAsync();

        // 异步发送紧急呼叫通知给子女（不阻塞主流程）
        _ = Task.Run(async () =>
        {
            try
            {
                await SendEmergencyNotificationAsync(elderId, familyMember.User.RealName, call.Id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "紧急呼叫通知发送失败，老人 {ElderId}", elderId);
            }
        });

        // 异步广播给邻里圈附近邻居（不阻塞主流程）
        _ = Task.Run(async () =>
        {
            try
            {
                await _neighborHelpService.BroadcastHelpRequestAsync(call.Id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "邻里互助广播失败，呼叫 {CallId}", call.Id);
            }
        });

        // 安排二次提醒检查（如果无人响应则再次通知）
        BackgroundJob.Schedule<EmergencyService>(
            svc => svc.CheckAndSendFollowUpAsync(call.Id),
            TimeSpan.FromMinutes(_followUpDelayMinutes));

        // 返回响应
        return new EmergencyCallResponse
        {
            Id = call.Id,
            ElderId = call.ElderId,
            ElderName = familyMember.User.RealName,
            ElderPhoneNumber = familyMember.User.PhoneNumber.MaskPhoneNumber(),
            FamilyId = call.FamilyId,
            CalledAt = call.CalledAt,
            Status = call.Status,
            Latitude = call.Latitude,
            Longitude = call.Longitude,
            BatteryLevel = call.BatteryLevel,
        };
    }

    /// <summary>
    /// 检查并发送二次提醒（由 Hangfire 定时调用）
    /// </summary>
    public async Task CheckAndSendFollowUpAsync(Guid callId)
    {
        var call = await _context.EmergencyCalls
            .AsTracking()
            .Include(c => c.Elder)
            .FirstOrDefaultAsync(c => c.Id == callId);

        // 呼叫已被响应或已提醒过，跳过
        if (call == null || call.Status == EmergencyStatus.Responded || call.Reminded)
            return;

        call.Reminded = true;
        await _context.SaveChangesAsync();

        // 发送二次提醒通知
        await SendEmergencyNotificationAsync(call.ElderId, call.Elder.RealName, call.Id, isReminder: true);

        _logger.LogInformation("紧急呼叫 {CallId} 已发送二次提醒", callId);
    }

    /// <summary>
    /// 发送紧急呼叫通知给子女（SignalR + SMS 多通道）
    /// </summary>
    private async Task SendEmergencyNotificationAsync(Guid elderId, string elderName, Guid callId, bool isReminder = false)
    {
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == elderId);

        if (familyMember == null) return;

        var children = await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.FamilyId == familyMember.FamilyId && fm.Role == UserRole.Child)
            .ToListAsync();

        if (children.Count > 0)
        {
            // SignalR 推送通知
            await _notificationService.SendToUsersAsync(
                children.Select(c => c.UserId),
                isReminder ? "EmergencyCallReminder" : "EmergencyCall",
                new
                {
                    Title = isReminder ? "紧急呼叫仍未响应" : "紧急呼叫",
                    Content = isReminder
                        ? $"{elderName}的紧急呼叫已超过3分钟未得到响应，请尽快处理！"
                        : $"{elderName}发起了紧急呼叫，请尽快处理！",
                    ElderId = elderId,
                    ElderName = elderName,
                    CallId = callId,
                    IsReminder = isReminder,
                }
            );

            // SMS 多通道告警（异步发送，不阻塞主流程）
            _ = Task.Run(async () =>
            {
                try
                {
                    await SendSmsAlertToChildrenAsync(children, elderName, callId, isReminder);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "紧急呼叫 SMS 告警发送失败，呼叫 {CallId}", callId);
                }
            });
        }
    }

    /// <summary>
    /// 发送 SMS 告警给子女（多通道告警）
    /// </summary>
    private async Task SendSmsAlertToChildrenAsync(
        List<FamilyMember> children,
        string elderName,
        Guid callId,
        bool isReminder)
    {
        foreach (var child in children)
        {
            var content = isReminder
                ? $"【紧急提醒】{elderName}的紧急呼叫已超过3分钟未响应，请尽快处理！"
                : $"【紧急呼叫】{elderName}发起了紧急呼叫，请立即查看并处理！";

            var (success, errorMessage) = await _smsService.SendAsync(child.User.PhoneNumber, content);

            // 记录短信发送结果
            var smsRecord = new SmsRecord
            {
                Id = Guid.NewGuid(),
                PhoneNumber = child.User.PhoneNumber,
                Content = content,
                ServiceName = _smsService.ServiceName,
                Success = success,
                ErrorMessage = errorMessage,
                RelatedEmergencyCallId = callId,
                CreatedAt = DateTime.UtcNow,
            };

            _context.SmsRecords.Add(smsRecord);
            await _context.SaveChangesAsync();

            if (success)
            {
                _logger.LogInformation("紧急呼叫 SMS 已发送: 呼叫={CallId}, 子女={ChildId}, 服务={Service}",
                    callId, child.UserId, _smsService.ServiceName);
            }
            else
            {
                _logger.LogWarning("紧急呼叫 SMS 发送失败: 呼叫={CallId}, 子女={ChildId}, 错误={Error}",
                    callId, child.UserId, errorMessage);
            }
        }
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
            ElderPhoneNumber = c.Elder.PhoneNumber.MaskPhoneNumber(),
            FamilyId = c.FamilyId,
            CalledAt = c.CalledAt,
            Status = c.Status,
            Latitude = c.Latitude,
            Longitude = c.Longitude,
            BatteryLevel = c.BatteryLevel,
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
            ElderPhoneNumber = c.Elder.PhoneNumber.MaskPhoneNumber(),
            FamilyId = c.FamilyId,
            CalledAt = c.CalledAt,
            Status = c.Status,
            RespondedBy = c.RespondedBy,
            RespondedByRealName = c.RespondedByRealName,
            RespondedAt = c.RespondedAt,
            Latitude = c.Latitude,
            Longitude = c.Longitude,
            BatteryLevel = c.BatteryLevel,
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
            ElderPhoneNumber = call.Elder.PhoneNumber.MaskPhoneNumber(),
            FamilyId = call.FamilyId,
            CalledAt = call.CalledAt,
            Status = call.Status,
            RespondedBy = call.RespondedBy,
            RespondedByRealName = call.RespondedByRealName,
            RespondedAt = call.RespondedAt,
            Latitude = call.Latitude,
            Longitude = call.Longitude,
            BatteryLevel = call.BatteryLevel,
        };
    }
}