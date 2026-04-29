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
        _followUpDelayMinutes = configuration?.GetValue(ConfigurationKeys.Emergency.FollowUpDelayMinutes, AppConstants.Emergency.FollowUpDelayMinutes) ?? AppConstants.Emergency.FollowUpDelayMinutes;
    }

    /// <summary>
    /// 老人发起紧急呼叫
    /// </summary>
    public async Task<EmergencyCallResponse> CreateCallAsync(Guid elderId, double? latitude = null, double? longitude = null, int? batteryLevel = null, CancellationToken cancellationToken = default)
    {
        // 防重复提交：同一老人 30 秒内的重复请求视为同一呼叫，返回已有记录
        var recentCall = await _context.EmergencyCalls
            .Include(c => c.Elder)
            .Where(c => c.ElderId == elderId && c.CalledAt > DateTime.UtcNow.AddSeconds(-30))
            .OrderByDescending(c => c.CalledAt)
            .FirstOrDefaultAsync(cancellationToken);

        if (recentCall != null)
            return MapToResponse(recentCall);

        // 获取老人的家庭信息
        var familyMember = await _context.FamilyMembers
            .Include(fm => fm.User)
            .FirstOrDefaultAsync(fm => fm.UserId == elderId, cancellationToken);

        if (familyMember == null)
            throw new InvalidOperationException(ErrorMessages.Family.NotInAnyFamily);

        if (familyMember.User == null)
            throw new InvalidOperationException(ErrorMessages.Emergency.ElderUserInfoInvalid);

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
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogWarning("紧急呼叫已创建：老人 {ElderId}，呼叫 {CallId}，电量 {BatteryLevel}", elderId, call.Id, batteryLevel);

        // 异步发送紧急呼叫通知给子女（通过 Hangfire 持久化，失败时同步兜底）
        try
        {
            BackgroundJob.Enqueue(() => SendEmergencyNotificationJobAsync(
                elderId, familyMember.User.RealName, call.Id));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "紧急呼叫通知入队失败，尝试同步兜底发送，呼叫 {CallId}", call.Id);
            // Hangfire 不可用时同步发送，确保子女能收到通知
            try
            {
                await SendEmergencyNotificationJobAsync(elderId, familyMember.User.RealName, call.Id);
            }
            catch (Exception fallbackEx)
            {
                _logger.LogError(fallbackEx, "紧急呼叫同步兜底发送也失败，呼叫 {CallId}，需人工关注！", call.Id);
            }
        }

        // 异步广播给邻里圈附近邻居（通过 Hangfire 持久化）
        try
        {
            BackgroundJob.Enqueue<INeighborHelpService>(
                svc => svc.BroadcastHelpRequestAsync(call.Id));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "邻里广播入队失败，呼叫 {CallId}", call.Id);
        }

        // 安排二次提醒检查（如果无人响应则再次通知）
        try
        {
            BackgroundJob.Schedule<EmergencyService>(
                svc => svc.CheckAndSendFollowUpAsync(call.Id),
                TimeSpan.FromMinutes(_followUpDelayMinutes));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "二次提醒调度失败，呼叫 {CallId}", call.Id);
        }

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
    /// 幂等保护：呼叫已响应时跳过通知，避免 Hangfire 重试导致骚扰
    /// </summary>
    public async Task SendEmergencyNotificationJobAsync(Guid elderId, string elderName, Guid callId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(elderName, nameof(elderName));

        // 幂等检查：呼叫已响应则跳过通知
        var callStatus = await _context.EmergencyCalls
            .Where(c => c.Id == callId)
            .Select(c => (EmergencyStatus?)c.Status)
            .FirstOrDefaultAsync();

        if (callStatus == null || callStatus == EmergencyStatus.Responded)
        {
            _logger.LogInformation("紧急呼叫 {CallId} 已响应或不存在，跳过通知发送", callId);
            return;
        }

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
        var children = await GetChildrenAsync(elderId);

        if (!children.Any()) return;

        var childUserIds = children.Select(c => c.UserId).ToList();
        var (title, content) = BuildNotificationContent(isReminder, elderName);

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
            try
            {
                BackgroundJob.Enqueue<EmergencyService>(svc => svc.SendFcmPushJobAsync(
                    fcmChildIds, fcmTitle, fcmContent, fcmType,
                    callId.ToString(), elderId.ToString(), elderName));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "FCM 推送入队失败，呼叫 {CallId}", callId);
            }

            // SMS 多通道告警（最终兜底），通过 Hangfire 异步发送
            try
            {
                BackgroundJob.Enqueue<EmergencyService>(svc => svc.SendSmsAlertJobAsync(callId, isReminder));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "SMS 告警入队失败，呼叫 {CallId}", callId);
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
        // 短信内容模板对所有子女相同，提取到循环外避免重复格式化
        var smsContent = isReminder
            ? string.Format(NotificationMessages.Emergency.SmsReminderContentTemplate, elderName)
            : string.Format(NotificationMessages.Emergency.SmsCallContentTemplate, elderName);

        // 并行发送 SMS 给所有子女（紧急场景下延迟敏感，串行发送不可接受）
        var smsTasks = children.Select(async child =>
        {
            var (success, errorMessage) = (false, ErrorMessages.Sms.SendFailed);
            try
            {
                (success, errorMessage) = await _smsService.SendAsync(child.User.PhoneNumber, smsContent);
            }
            catch (Exception ex)
            {
                errorMessage = ErrorMessages.Sms.SendFailed;
                _logger.LogError(ex, "紧急呼叫 SMS 发送异常: 呼叫={CallId}, 子女={ChildId}",
                    callId, child.UserId);
            }

            if (success)
            {
                _logger.LogInformation("紧急呼叫 SMS 已发送: 呼叫={CallId}, 子女={ChildId}, 服务={Service}",
                    callId, child.UserId, _smsService.ServiceName);
            }

            return new SmsRecord
            {
                Id = Guid.NewGuid(),
                PhoneNumber = child.User.PhoneNumber,
                Content = smsContent,
                ServiceName = _smsService.ServiceName,
                Success = success,
                ErrorMessage = errorMessage,
                RelatedEmergencyCallId = callId,
                CreatedAt = DateTime.UtcNow,
            };
        }).ToList();

        var smsRecords = await Task.WhenAll(smsTasks);

        // 一次性批量写入所有短信记录
        if (smsRecords.Any())
        {
            _context.SmsRecords.AddRange(smsRecords);
            await _context.SaveChangesAsync();
            _logger.LogInformation("紧急呼叫 SMS 记录已保存：呼叫 {CallId}，记录数 {Count}", callId, smsRecords.Length);
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
    /// 幂等保护：呼叫已响应时跳过 SMS，避免重复发送浪费短信配额
    /// </summary>
    public async Task SendSmsAlertJobAsync(Guid callId, bool isReminder)
    {
        try
        {
            var call = await _context.EmergencyCalls
                .Include(c => c.Elder)
                .FirstOrDefaultAsync(c => c.Id == callId);

            if (call == null) return;

            // 幂等检查：呼叫已响应则跳过 SMS（二次提醒除外）
            if (!isReminder && call.Status == EmergencyStatus.Responded)
            {
                _logger.LogInformation("紧急呼叫 {CallId} 已响应，跳过 SMS 发送", callId);
                return;
            }

            var children = await GetChildrenAsync(call.ElderId);

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
    public async Task<List<EmergencyCallResponse>> GetUnreadCallsAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        // 获取子女的家庭信息
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == userId, cancellationToken);

        if (familyMember == null)
            return [];

        // 获取该家庭中未处理的紧急呼叫
        var calls = await _context.EmergencyCalls
            .Include(c => c.Elder)
            .Where(c => c.FamilyId == familyMember.FamilyId && c.Status == EmergencyStatus.Pending)
            .OrderByDescending(c => c.CalledAt)
            .ToListAsync(cancellationToken);

        return calls.Select(MapToResponse).ToList();
    }

    /// <summary>
    /// 获取历史呼叫记录
    /// </summary>
    public async Task<List<EmergencyCallResponse>> GetHistoryAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default)
    {
        // 获取用户的家庭信息
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == userId, cancellationToken);

        if (familyMember == null)
            return [];

        // 获取该家庭的所有紧急呼叫记录
        var calls = await _context.EmergencyCalls
            .Include(c => c.Elder)
            .Where(c => c.FamilyId == familyMember.FamilyId)
            .OrderByDescending(c => c.CalledAt)
            .Skip(skip)
            .Take(limit)
            .ToListAsync(cancellationToken);

        return calls.Select(MapToResponse).ToList();
    }

    /// <summary>
    /// 子女标记已处理（原子更新防止多子女并发响应覆盖）
    /// </summary>
    public async Task<EmergencyCallResponse> RespondCallAsync(Guid callId, Guid userId, CancellationToken cancellationToken = default)
    {
        // 获取用户信息
        var user = await _context.Users.FindAsync([userId], cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 获取呼叫记录（无需 AsTracking，使用原子更新）
        var call = await _context.EmergencyCalls
            .FirstOrDefaultAsync(c => c.Id == callId, cancellationToken);

        if (call == null)
            throw new KeyNotFoundException(ErrorMessages.Emergency.CallNotFound);

        if (call.Status == EmergencyStatus.Responded)
            throw new InvalidOperationException(ErrorMessages.Emergency.CallAlreadyResponded);

        // 验证用户是否是该家庭成员
        var isMember = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == userId && fm.FamilyId == call.FamilyId, cancellationToken);

        if (!isMember)
            throw new UnauthorizedAccessException(ErrorMessages.Emergency.NotFamilyMemberForCall);

        // 原子更新：只有 Status 仍为 Pending 时才更新，防止多子女并发覆盖
        var now = DateTime.UtcNow;
        var callToUpdate = await _context.EmergencyCalls
            .AsTracking()
            .FirstOrDefaultAsync(c => c.Id == callId && c.Status == EmergencyStatus.Pending, cancellationToken);

        if (callToUpdate == null)
            throw new InvalidOperationException(ErrorMessages.Emergency.CallAlreadyResponded);

        callToUpdate.Status = EmergencyStatus.Responded;
        callToUpdate.RespondedBy = userId;
        callToUpdate.RespondedByRealName = user.RealName;
        callToUpdate.RespondedAt = now;
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("紧急呼叫已响应：呼叫 {CallId}，响应人 {UserId}（{RealName}）",
            callId, userId, user.RealName);

        // 重新查询完整记录返回响应
        var respondedCall = await _context.EmergencyCalls
            .Include(c => c.Elder)
            .FirstAsync(c => c.Id == callId, cancellationToken);

        return MapToResponse(respondedCall);
    }

    /// <summary>
    /// 将 EmergencyCall 实体映射为响应 DTO
    /// </summary>
    private static EmergencyCallResponse MapToResponse(EmergencyCall c) => new()
    {
        Id = c.Id,
        ElderId = c.ElderId,
        ElderName = c.Elder?.RealName ?? string.Empty,
        ElderPhoneNumber = c.Elder?.PhoneNumber.MaskPhoneNumber() ?? string.Empty,
        FamilyId = c.FamilyId,
        CalledAt = c.CalledAt,
        Status = c.Status,
        RespondedBy = c.RespondedBy,
        RespondedByRealName = c.RespondedByRealName,
        RespondedAt = c.RespondedAt,
        Latitude = c.Latitude,
        Longitude = c.Longitude,
        BatteryLevel = c.BatteryLevel,
    };

    /// <summary>
    /// 根据是否为二次提醒构建通知标题和内容
    /// </summary>
    private static (string Title, string Content) BuildNotificationContent(bool isReminder, string elderName)
    {
        return isReminder
            ? (NotificationMessages.Emergency.CallReminderTitle,
               string.Format(NotificationMessages.Emergency.CallReminderContentTemplate, elderName))
            : (NotificationMessages.Emergency.CallTitle,
               string.Format(NotificationMessages.Emergency.CallContentTemplate, elderName));
    }

    /// <summary>
    /// 查询指定老人所在家庭的子女成员列表（含用户信息）
    /// </summary>
    private async Task<List<FamilyMember>> GetChildrenAsync(Guid elderId)
    {
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == elderId);

        if (familyMember == null) return [];

        return await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.FamilyId == familyMember.FamilyId && fm.Role == UserRole.Child)
            .ToListAsync();
    }
}