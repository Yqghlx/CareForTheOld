using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using Hangfire;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 邻里互助服务实现
/// </summary>
public class NeighborHelpService : INeighborHelpService
{
    private readonly AppDbContext _context;
    private readonly INotificationService _notificationService;
    private readonly ITrustScoreService _trustScoreService;
    private readonly IFamilyService _familyService;
    private readonly ILogger<NeighborHelpService> _logger;

    /// <summary>求助请求默认过期时间</summary>
    private static readonly TimeSpan _defaultExpiration = TimeSpan.FromMinutes(AppConstants.NeighborHelp.DefaultExpirationMinutes);

    /// <summary>广播距离阈值（米），只通知此范围内的邻居</summary>
    private const double BroadcastRadiusMeters = AppConstants.NeighborHelp.BroadcastRadiusMeters;

    public NeighborHelpService(
        AppDbContext context,
        INotificationService notificationService,
        ITrustScoreService trustScoreService,
        IFamilyService familyService,
        ILogger<NeighborHelpService> logger)
    {
        _context = context;
        _notificationService = notificationService;
        _trustScoreService = trustScoreService;
        _familyService = familyService;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task BroadcastHelpRequestAsync(Guid emergencyCallId, CancellationToken cancellationToken = default)
    {
        // 获取紧急呼叫记录
        var call = await _context.EmergencyCalls
            .Include(c => c.Elder)
            .FirstOrDefaultAsync(c => c.Id == emergencyCallId, cancellationToken);

        if (call == null)
        {
            _logger.LogWarning("广播邻里求助失败：紧急呼叫 {CallId} 不存在", emergencyCallId);
            return;
        }

        // 查找老人加入的邻里圈
        var membership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == call.ElderId, cancellationToken);

        if (membership == null)
        {
            _logger.LogInformation("老人 {ElderId} 未加入任何邻里圈，跳过邻里广播", call.ElderId);
            return;
        }

        var circleId = membership.CircleId;

        // 如果没有位置信息，无法计算距离，广播给全圈成员
        if (!call.Latitude.HasValue || !call.Longitude.HasValue)
        {
            _logger.LogInformation("紧急呼叫 {CallId} 无位置信息，广播给全圈成员", emergencyCallId);
            await BroadcastToAllMembersAsync(call, circleId, cancellationToken);
            return;
        }

        // 获取圈子成员（排除求助者本人）
        var memberIds = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == circleId && m.UserId != call.ElderId)
            .Select(m => m.UserId)
            .ToListAsync(cancellationToken);

        if (!memberIds.Any())
        {
            _logger.LogInformation("邻里圈 {CircleId} 无其他成员", circleId);
            return;
        }

        // 获取成员最近位置记录
        var recentLocations = await _context.LocationRecords
            .Where(l => memberIds.Contains(l.UserId))
            .GroupBy(l => l.UserId)
            .Select(g => g.OrderByDescending(l => l.RecordedAt).First())
            .ToListAsync(cancellationToken);

        // 粗筛 + Haversine 精算，筛选广播半径内的邻居
        var nearbyUserIds = new List<Guid>();
        var lat = call.Latitude.Value;
        var lng = call.Longitude.Value;
        var (latThreshold, lngThreshold) = GeoHelper.CalculateDegreeThresholds(BroadcastRadiusMeters, lat);

        foreach (var loc in recentLocations)
        {
            if (Math.Abs(loc.Latitude - lat) > latThreshold ||
                Math.Abs(loc.Longitude - lng) > lngThreshold)
                continue;

            var distance = GeoHelper.HaversineDistance(lat, lng, loc.Latitude, loc.Longitude);
            if (distance <= BroadcastRadiusMeters)
                nearbyUserIds.Add(loc.UserId);
        }

        // 如果附近没有邻居，广播给全圈作为兜底
        if (!nearbyUserIds.Any())
        {
            _logger.LogInformation("紧急呼叫 {CallId} 附近 {Radius} 米无邻居，广播给全圈成员",
                emergencyCallId, BroadcastRadiusMeters);
            nearbyUserIds = memberIds;
        }

        // 按信任评分降序排序，高信用邻居优先推送
        var nearbyWithScores = await _trustScoreService.GetUserScoresAsync(nearbyUserIds, circleId, cancellationToken);
        nearbyUserIds = nearbyWithScores
            .OrderByDescending(kv => kv.Value)
            .Select(kv => kv.Key)
            .ToList();

        // 创建求助请求记录
        var now = DateTime.UtcNow;
        var helpRequest = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = emergencyCallId,
            CircleId = circleId,
            RequesterId = call.ElderId,
            Status = HelpRequestStatus.Pending,
            Latitude = call.Latitude,
            Longitude = call.Longitude,
            RequestedAt = now,
            ExpiresAt = now.Add(_defaultExpiration),
        };

        _context.NeighborHelpRequests.Add(helpRequest);

        // 批量记录通知日志（用于后续计算响应率）
        _context.HelpNotificationLogs.AddRange(nearbyUserIds.Select(neighborId =>
            new HelpNotificationLog
            {
                Id = Guid.NewGuid(),
                HelpRequestId = helpRequest.Id,
                UserId = neighborId,
                NotifiedAt = now,
            }));

        // 一次性保存请求和通知日志，减少数据库交互
        await _context.SaveChangesAsync(cancellationToken);

        // Outbox Pattern 推送通知给附近邻居
        await _notificationService.SendToUsersAsync(
            nearbyUserIds,
            AppConstants.NotificationTypes.NeighborHelpRequest,
            new
            {
                Title = NotificationMessages.NeighborHelp.EmergencyRequestTitle,
                Content = string.Format(NotificationMessages.NeighborHelp.EmergencyRequestNeighborContentTemplate, call.Elder.RealName),
                HelpRequestId = helpRequest.Id,
                EmergencyCallId = emergencyCallId,
                RequesterId = call.ElderId,
                RequesterName = call.Elder.RealName,
                Latitude = call.Latitude,
                Longitude = call.Longitude,
                ExpiresAt = helpRequest.ExpiresAt,
            },
            cancellationToken);

        _logger.LogInformation(
            "已广播邻里求助：呼叫={CallId}, 请求={RequestId}, 通知邻居数={Count}",
            emergencyCallId, helpRequest.Id, nearbyUserIds.Count);
    }

    /// <inheritdoc />
    public async Task<NeighborHelpRequestResponse> AcceptHelpRequestAsync(Guid requestId, Guid responderId, CancellationToken cancellationToken = default)
    {
        var request = await _context.NeighborHelpRequests
            .Include(r => r.Requester)
            .FirstOrDefaultAsync(r => r.Id == requestId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborHelp.RequestNotFound);

        if (request.Status != HelpRequestStatus.Pending)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.InvalidStatus);

        if (request.ExpiresAt < DateTime.UtcNow)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.RequestExpired);

        if (request.RequesterId == responderId)
            throw new ArgumentException(ErrorMessages.NeighborHelp.CannotAcceptOwn);

        // 原子更新：只有 Status 仍为 Pending 时才更新，防止多邻居并发接受
        var now = DateTime.UtcNow;
        var requestToUpdate = await _context.NeighborHelpRequests
            .AsTracking()
            .FirstOrDefaultAsync(r => r.Id == requestId && r.Status == HelpRequestStatus.Pending, cancellationToken);

        if (requestToUpdate == null)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.InvalidStatus);

        requestToUpdate.Status = HelpRequestStatus.Accepted;
        requestToUpdate.ResponderId = responderId;
        requestToUpdate.RespondedAt = now;

        // 同一事务中更新通知日志，确保数据一致性
        var notifyLog = await _context.HelpNotificationLogs
            .AsTracking()
            .FirstOrDefaultAsync(h => h.HelpRequestId == requestId && h.UserId == responderId, cancellationToken);
        if (notifyLog != null)
        {
            notifyLog.RespondedAt = now;
        }

        await _context.SaveChangesAsync(cancellationToken);

        // 查询响应者信息
        var responder = await _context.Users.FindAsync([responderId], cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.ResponderNotFound);

        // 通知老人："邻居XX正在赶来"
        await _notificationService.SendToUserAsync(
            request.RequesterId,
            AppConstants.NotificationTypes.NeighborHelpAccepted,
            new
            {
                Title = NotificationMessages.NeighborHelp.HelperComingTitle,
                Content = string.Format(NotificationMessages.NeighborHelp.HelperComingContentTemplate, responder.RealName),
                HelpRequestId = requestId,
                ResponderName = responder.RealName,
            },
            cancellationToken);

        // 通知老人的子女："邻居已响应紧急呼叫"
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == request.RequesterId, cancellationToken);
        if (familyMember != null)
        {
            var childIds = await _familyService.GetChildUserIdsAsync(familyMember.FamilyId, cancellationToken);

            if (childIds.Any())
            {
                await _notificationService.SendToUsersAsync(
                    childIds,
                    AppConstants.NotificationTypes.NeighborHelpAccepted,
                    new
                    {
                        Title = NotificationMessages.NeighborHelp.HelperRespondedTitle,
                        Content = string.Format(NotificationMessages.NeighborHelp.HelperRespondedContentTemplate, responder.RealName, request.Requester.RealName),
                        HelpRequestId = requestId,
                        EmergencyCallId = request.EmergencyCallId,
                        ResponderName = responder.RealName,
                    },
                    cancellationToken);
            }
        }

        // 通知其他邻居："该求助已被接受"
        var otherMemberIds = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == request.CircleId &&
                        m.UserId != responderId &&
                        m.UserId != request.RequesterId)
            .Select(m => m.UserId)
            .ToListAsync(cancellationToken);

        if (otherMemberIds.Any())
        {
            await _notificationService.SendToUsersAsync(
                otherMemberIds,
                AppConstants.NotificationTypes.NeighborHelpResolved,
                new
                {
                    Title = NotificationMessages.NeighborHelp.RequestRespondedTitle,
                    Content = string.Format(NotificationMessages.NeighborHelp.RequestAcceptedContentTemplate, request.Requester.RealName, responder.RealName),
                    HelpRequestId = requestId,
                },
                cancellationToken);
        }

        _logger.LogInformation("邻居 {ResponderId} 已接受求助请求 {RequestId}，求助者 {RequesterId}", responderId, requestId, request.RequesterId);

        return await BuildHelpRequestResponse(request.Id, cancellationToken);
    }

    /// <inheritdoc />
    public async Task CancelHelpRequestAsync(Guid requestId, Guid operatorId, CancellationToken cancellationToken = default)
    {
        var request = await _context.NeighborHelpRequests
            .AsTracking()
            .Include(r => r.Requester)
            .FirstOrDefaultAsync(r => r.Id == requestId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborHelp.RequestNotFound);

        if (request.Status != HelpRequestStatus.Pending && request.Status != HelpRequestStatus.Accepted)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.InvalidStatus);

        // 验证操作者：老人本人或其子女
        if (!await IsRequesterOrFamilyChildAsync(request.RequesterId, operatorId, cancellationToken))
            throw new UnauthorizedAccessException(ErrorMessages.NeighborHelp.OnlyRequesterOrChildCancel);

        request.Status = HelpRequestStatus.Cancelled;
        request.CancelledAt = DateTime.UtcNow;
        request.CancelledBy = operatorId;

        // 关闭该请求所有未响应的通知日志
        var pendingLogs = await _context.HelpNotificationLogs
            .AsTracking()
            .Where(h => h.HelpRequestId == requestId && h.RespondedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var log in pendingLogs)
        {
            // 设为取消时间表示未响应（保持 RespondedAt 为 null，统计时视为未响应）
            log.RespondedAt = null;
        }

        await _context.SaveChangesAsync(cancellationToken);

        // 通知已响应的邻居
        if (request.ResponderId.HasValue)
        {
            await _notificationService.SendToUserAsync(
                request.ResponderId.Value,
                AppConstants.NotificationTypes.NeighborHelpCancelled,
                new
                {
                    Title = NotificationMessages.NeighborHelp.RequestCancelledTitle,
                    Content = string.Format(NotificationMessages.NeighborHelp.RequestCancelledContentTemplate, request.Requester.RealName),
                    HelpRequestId = requestId,
                },
                cancellationToken);
        }

        _logger.LogInformation("求助请求 {RequestId} 已被用户 {OperatorId} 取消", requestId, operatorId);
    }

    /// <inheritdoc />
    public async Task<NeighborHelpRatingResponse> RateHelpRequestAsync(
        Guid requestId, Guid raterId, RateHelpRequest request, CancellationToken cancellationToken = default)
    {
        var helpRequest = await _context.NeighborHelpRequests
            .FirstOrDefaultAsync(r => r.Id == requestId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborHelp.RequestNotFound);

        if (helpRequest.Status != HelpRequestStatus.Accepted)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.CanOnlyRateAccepted);

        if (helpRequest.ResponderId == null)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.NotRespondedCannotRate);

        // 验证评价者：老人本人或其子女
        if (!await IsRequesterOrFamilyChildAsync(helpRequest.RequesterId, raterId, cancellationToken))
            throw new UnauthorizedAccessException(ErrorMessages.NeighborHelp.OnlyRequesterOrChildRate);

        // 应用层检查：同一用户对同一请求不能重复评价
        if (await _context.NeighborHelpRatings.AnyAsync(r => r.HelpRequestId == requestId && r.RaterId == raterId, cancellationToken))
            throw new ArgumentException(ErrorMessages.NeighborHelp.AlreadyRated);

        var rating = new NeighborHelpRating
        {
            Id = Guid.NewGuid(),
            HelpRequestId = requestId,
            RaterId = raterId,
            RateeId = helpRequest.ResponderId.Value,
            Rating = request.Rating,
            Comment = request.Comment,
            CreatedAt = DateTime.UtcNow
        };

        _context.NeighborHelpRatings.Add(rating);

        try
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.NeighborHelp.AlreadyRated);
        }

        _logger.LogInformation("用户 {RaterId} 对求助 {RequestId} 的响应者 {RateeId} 评分 {Rating}", raterId, requestId, helpRequest.ResponderId, request.Rating);

        return new NeighborHelpRatingResponse
        {
            Id = rating.Id,
            HelpRequestId = rating.HelpRequestId,
            RaterId = rating.RaterId,
            RateeId = rating.RateeId,
            Rating = rating.Rating,
            Comment = rating.Comment,
            CreatedAt = rating.CreatedAt
        };
    }

    /// <inheritdoc />
    public async Task<List<NeighborHelpRequestResponse>> GetPendingRequestsAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        // 查找用户加入的邻里圈
        var membership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == userId, cancellationToken);

        if (membership == null)
            return [];

        var now = DateTime.UtcNow;

        return await _context.NeighborHelpRequests
            .Include(r => r.Requester)
            .Include(r => r.Responder)
            .Where(r => r.CircleId == membership.CircleId &&
                        r.Status == HelpRequestStatus.Pending &&
                        r.ExpiresAt > now &&
                        r.RequesterId != userId)
            .OrderByDescending(r => r.RequestedAt)
            .Take(AppConstants.NeighborHelp.MaxPendingRequests)
            .Select(r => MapToResponse(r))
            .ToListAsync(cancellationToken);
    }

    /// <inheritdoc />
    public async Task<List<NeighborHelpRequestResponse>> GetHistoryAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default)
    {
        // 查找用户加入的邻里圈
        var membership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == userId, cancellationToken);

        if (membership == null)
            return [];

        return await _context.NeighborHelpRequests
            .Include(r => r.Requester)
            .Include(r => r.Responder)
            .Where(r => r.CircleId == membership.CircleId &&
                        (r.RequesterId == userId || r.ResponderId == userId))
            .OrderByDescending(r => r.RequestedAt)
            .Skip(skip)
            .Take(limit)
            .Select(r => MapToResponse(r))
            .ToListAsync(cancellationToken);
    }

    /// <inheritdoc />
    public async Task<NeighborHelpRequestResponse> GetRequestAsync(Guid requestId, CancellationToken cancellationToken = default)
    {
        return await BuildHelpRequestResponse(requestId, cancellationToken);
    }

    /// <inheritdoc />
    // 重试策略参考 AppConstants.HangfireRetry
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = new[] { 10, 30 })]
    public async Task CleanupExpiredRequestsAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var expiredRequests = await _context.NeighborHelpRequests
            .AsTracking()
            .Where(r => r.Status == HelpRequestStatus.Pending && r.ExpiresAt < now)
            .ToListAsync(cancellationToken);

        if (!expiredRequests.Any())
            return;

        var expiredIds = expiredRequests.Select(r => r.Id).ToList();

        foreach (var request in expiredRequests)
        {
            request.Status = HelpRequestStatus.Expired;
        }

        // 关闭过期请求的未响应通知日志
        var pendingLogs = await _context.HelpNotificationLogs
            .AsTracking()
            .Where(h => expiredIds.Contains(h.HelpRequestId) && h.RespondedAt == null)
            .ToListAsync(cancellationToken);
        // 过期的通知日志保持 RespondedAt 为 null，表示未响应

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("已清理 {Count} 个过期邻里求助请求", expiredRequests.Count);
    }

    /// <summary>
    /// 无位置信息时，广播给全圈成员
    /// </summary>
    private async Task BroadcastToAllMembersAsync(EmergencyCall call, Guid circleId, CancellationToken cancellationToken = default)
    {
        var memberIds = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == circleId && m.UserId != call.ElderId)
            .Select(m => m.UserId)
            .ToListAsync(cancellationToken);

        if (!memberIds.Any()) return;

        var requestNow = DateTime.UtcNow;
        var helpRequest = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = call.Id,
            CircleId = circleId,
            RequesterId = call.ElderId,
            Status = HelpRequestStatus.Pending,
            Latitude = call.Latitude,
            Longitude = call.Longitude,
            RequestedAt = requestNow,
            ExpiresAt = requestNow.Add(_defaultExpiration),
        };

        _context.NeighborHelpRequests.Add(helpRequest);

        // 批量记录通知日志
        _context.HelpNotificationLogs.AddRange(memberIds.Select(memberId =>
            new HelpNotificationLog
            {
                Id = Guid.NewGuid(),
                HelpRequestId = helpRequest.Id,
                UserId = memberId,
                NotifiedAt = requestNow,
            }));

        // 一次性保存请求和通知日志
        await _context.SaveChangesAsync(cancellationToken);

        await _notificationService.SendToUsersAsync(
            memberIds,
            AppConstants.NotificationTypes.NeighborHelpRequest,
            new
            {
                Title = NotificationMessages.NeighborHelp.EmergencyRequestTitle,
                Content = string.Format(NotificationMessages.NeighborHelp.EmergencyRequestContentTemplate, call.Elder.RealName),
                HelpRequestId = helpRequest.Id,
                EmergencyCallId = call.Id,
                RequesterId = call.ElderId,
                RequesterName = call.Elder.RealName,
                Latitude = call.Latitude,
                Longitude = call.Longitude,
                ExpiresAt = helpRequest.ExpiresAt,
            },
            cancellationToken);
    }

    /// <summary>
    /// 构建求助请求响应
    /// </summary>
    private async Task<NeighborHelpRequestResponse> BuildHelpRequestResponse(Guid requestId, CancellationToken cancellationToken = default)
    {
        var request = await _context.NeighborHelpRequests
            .Include(r => r.Requester)
            .Include(r => r.Responder)
            .FirstAsync(r => r.Id == requestId, cancellationToken);

        return MapToResponse(request);
    }

    /// <summary>
    /// 将 NeighborHelpRequest 实体映射为响应 DTO
    /// </summary>
    private static NeighborHelpRequestResponse MapToResponse(NeighborHelpRequest r) => new()
    {
        Id = r.Id,
        EmergencyCallId = r.EmergencyCallId,
        CircleId = r.CircleId,
        RequesterId = r.RequesterId,
        RequesterName = r.Requester?.RealName ?? string.Empty,
        ResponderId = r.ResponderId,
        ResponderName = r.Responder != null ? r.Responder.RealName : null,
        Status = r.Status,
        Latitude = r.Latitude,
        Longitude = r.Longitude,
        RequestedAt = r.RequestedAt,
        RespondedAt = r.RespondedAt,
        ExpiresAt = r.ExpiresAt,
    };

    /// <summary>
    /// 验证操作者是否为请求者本人或其家庭成员（子女）
    /// </summary>
    private async Task<bool> IsRequesterOrFamilyChildAsync(Guid requesterId, Guid operatorId, CancellationToken cancellationToken = default)
    {
        if (requesterId == operatorId) return true;

        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == requesterId, cancellationToken);

        if (familyMember == null) return false;

        return await _context.FamilyMembers
            .AnyAsync(fm => fm.FamilyId == familyMember.FamilyId &&
                            fm.UserId == operatorId && fm.Role == UserRole.Child, cancellationToken);
    }
}
