using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Helpers;
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
    private readonly IPushNotificationService _pushNotificationService;
    private readonly ISmsService _smsService;
    private readonly INeighborHelpService _neighborHelpService;
    private readonly ILogger<EmergencyService> _logger;

    /// <summary>二次提醒延迟时间（默认 3 分钟）</summary>
    private readonly int _followUpDelayMinutes;

    public EmergencyService(
        AppDbContext context,
        INotificationService notificationService,
        IPushNotificationService pushNotificationService,
        ISmsService smsService,
        INeighborHelpService neighborHelpService,
        ILogger<EmergencyService> logger,
        IConfiguration? configuration = null)
    {
        _context = context;
        _notificationService = notificationService;
        _pushNotificationService = pushNotificationService;
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
            throw new InvalidOperationException(ErrorMessages.Family.NotInAnyFamily);

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

        // 异步发送紧急呼叫通知给子女（通过 Hangfire 持久化）
        BackgroundJob.Enqueue(() => SendEmergencyNotificationJobAsync(
            elderId, familyMember.User.RealName, call.Id));

        // 异步广播给邻里圈附近邻居（通过 Hangfire 持久化）
        BackgroundJob.Enqueue<INeighborHelpService>(
            svc => svc.BroadcastHelpRequestAsync(call.Id));

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
    /// Hangfire 后台任务：发送紧急呼叫通知给子女（SignalR + FCM + SMS）
    /// </summary>
    public async Task SendEmergencyNotificationJobAsync(Guid elderId, string elderName, Guid callId)
    {
        try
        {
            await SendEmergencyNotificationAsync(elderId, elderName, callId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "紧急呼叫通知发送失败，老人 {ElderId}", elderId);
        }
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
    /// 发送紧急呼叫通知给子女（SignalR + FCM + SMS 三通道）
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
            var childUserIds = children.Select(c => c.UserId).ToList();

            var title = isReminder ? "紧急呼叫仍未响应" : "紧急呼叫";
            var content = isReminder
                ? $"{elderName}的紧急呼叫已超过3分钟未得到响应，请尽快处理！"
                : $"{elderName}发起了紧急呼叫，请尽快处理！";

            // SignalR 推送通知（前台实时）
            await _notificationService.SendToUsersAsync(
                childUserIds,
                isReminder ? AppConstants.NotificationTypes.EmergencyCallReminder : AppConstants.NotificationTypes.EmergencyCall,
                new
                {
                    Title = title,
                    Content = content,
                    ElderId = elderId,
                    ElderName = elderName,
                    CallId = callId,
                    IsReminder = isReminder,
                }
            );

            // FCM 推送通知（后台/锁屏唤醒），通过 Hangfire 异步发送
            var fcmChildIds = childUserIds;
            var fcmTitle = title;
            var fcmContent = content;
            var fcmType = isReminder ? AppConstants.NotificationTypes.EmergencyReminderFcm : AppConstants.NotificationTypes.EmergencyCallFcm;
            BackgroundJob.Enqueue(() => SendFcmPushJobAsync(
                fcmChildIds, fcmTitle, fcmContent, fcmType,
                callId.ToString(), elderId.ToString(), elderName));

            // SMS 多通道告警（最终兜底），通过 Hangfire 异步发送
            BackgroundJob.Enqueue(() => SendSmsAlertJobAsync(callId, isReminder));
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
        // 批量收集 SmsRecord，循环结束后一次性写入数据库（避免 N+1）
        var smsRecords = new List<SmsRecord>();

        foreach (var child in children)
        {
            var content = isReminder
                ? $"【紧急提醒】{elderName}的紧急呼叫已超过3分钟未响应，请尽快处理！"
                : $"【紧急呼叫】{elderName}发起了紧急呼叫，请立即查看并处理！";

            var (success, errorMessage) = await _smsService.SendAsync(child.User.PhoneNumber, content);

            // 记录短信发送结果
            smsRecords.Add(new SmsRecord
            {
                Id = Guid.NewGuid(),
                PhoneNumber = child.User.PhoneNumber,
                Content = content,
                ServiceName = _smsService.ServiceName,
                Success = success,
                ErrorMessage = errorMessage,
                RelatedEmergencyCallId = callId,
                CreatedAt = DateTime.UtcNow,
            });

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

        // 一次性批量写入所有短信记录
        if (smsRecords.Count > 0)
        {
            _context.SmsRecords.AddRange(smsRecords);
            await _context.SaveChangesAsync();
        }
    }

    /// <summary>
    /// Hangfire 后台任务：发送 FCM 推送通知
    /// 参数为简单类型，确保 Hangfire 可序列化
    /// </summary>
    public async Task SendFcmPushJobAsync(
        List<Guid> childUserIds, string title, string content, string type,
        string callIdStr, string elderIdStr, string elderName)
    {
        try
        {
            await _pushNotificationService.SendAsync(
                childUserIds,
                title,
                content,
                new Dictionary<string, string>
                {
                    ["type"] = type,
                    ["callId"] = callIdStr,
                    ["elderId"] = elderIdStr,
                    ["elderName"] = elderName,
                });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "紧急呼叫 FCM 推送失败，呼叫 {CallId}", callIdStr);
        }
    }

    /// <summary>
    /// Hangfire 后台任务：发送 SMS 多通道告警
    /// 通过 callId 重新获取子女信息，避免序列化复杂对象
    /// </summary>
    public async Task SendSmsAlertJobAsync(Guid callId, bool isReminder)
    {
        try
        {
            var call = await _context.EmergencyCalls
                .Include(c => c.Elder)
                .FirstOrDefaultAsync(c => c.Id == callId);

            if (call == null) return;

            var familyMember = await _context.FamilyMembers
                .FirstOrDefaultAsync(fm => fm.UserId == call.ElderId);

            if (familyMember == null) return;

            var children = await _context.FamilyMembers
                .Include(fm => fm.User)
                .Where(fm => fm.FamilyId == familyMember.FamilyId && fm.Role == UserRole.Child)
                .ToListAsync();

            await SendSmsAlertToChildrenAsync(children, call.Elder.RealName, callId, isReminder);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "紧急呼叫 SMS 告警发送失败，呼叫 {CallId}", callId);
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
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 获取呼叫记录
        var call = await _context.EmergencyCalls
            .AsTracking()
            .Include(c => c.Elder)
            .FirstOrDefaultAsync(c => c.Id == callId);

        if (call == null)
            throw new KeyNotFoundException(ErrorMessages.Emergency.CallNotFound);

        if (call.Status == EmergencyStatus.Responded)
            throw new InvalidOperationException(ErrorMessages.Emergency.CallAlreadyResponded);

        // 验证用户是否是该家庭成员
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == userId && fm.FamilyId == call.FamilyId);

        if (!isMember)
            throw new UnauthorizedAccessException(ErrorMessages.Emergency.NotFamilyMemberForCall);

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