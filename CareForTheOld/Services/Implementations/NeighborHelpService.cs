using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
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
    private readonly ILogger<NeighborHelpService> _logger;

    /// <summary>求助请求默认过期时间</summary>
    private static readonly TimeSpan _defaultExpiration = TimeSpan.FromMinutes(AppConstants.NeighborHelp.DefaultExpirationMinutes);

    /// <summary>广播距离阈值（米），只通知此范围内的邻居</summary>
    private const double BroadcastRadiusMeters = AppConstants.NeighborHelp.BroadcastRadiusMeters;

    public NeighborHelpService(
        AppDbContext context,
        INotificationService notificationService,
        ITrustScoreService trustScoreService,
        ILogger<NeighborHelpService> logger)
    {
        _context = context;
        _notificationService = notificationService;
        _trustScoreService = trustScoreService;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task BroadcastHelpRequestAsync(Guid emergencyCallId)
    {
        // 获取紧急呼叫记录
        var call = await _context.EmergencyCalls
            .Include(c => c.Elder)
            .FirstOrDefaultAsync(c => c.Id == emergencyCallId);

        if (call == null)
        {
            _logger.LogWarning("广播邻里求助失败：紧急呼叫 {CallId} 不存在", emergencyCallId);
            return;
        }

        // 查找老人加入的邻里圈
        var membership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == call.ElderId);

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
            await BroadcastToAllMembersAsync(call, circleId);
            return;
        }

        // 获取圈子成员（排除求助者本人）
        var memberIds = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == circleId && m.UserId != call.ElderId)
            .Select(m => m.UserId)
            .ToListAsync();

        if (memberIds.Count == 0)
        {
            _logger.LogInformation("邻里圈 {CircleId} 无其他成员", circleId);
            return;
        }

        // 获取成员最近位置记录
        var recentLocations = await _context.LocationRecords
            .Where(l => memberIds.Contains(l.UserId))
            .GroupBy(l => l.UserId)
            .Select(g => g.OrderByDescending(l => l.RecordedAt).First())
            .ToListAsync();

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
        if (nearbyUserIds.Count == 0)
        {
            _logger.LogInformation("紧急呼叫 {CallId} 附近 {Radius} 米无邻居，广播给全圈成员",
                emergencyCallId, BroadcastRadiusMeters);
            nearbyUserIds = memberIds;
        }

        // 按信任评分降序排序，高信用邻居优先推送
        var nearbyWithScores = new Dictionary<Guid, decimal>();
        foreach (var uid in nearbyUserIds)
        {
            var s = await _trustScoreService.GetUserScoreAsync(uid, circleId);
            nearbyWithScores[uid] = s;
        }
        nearbyUserIds = nearbyWithScores
            .OrderByDescending(kv => kv.Value)
            .Select(kv => kv.Key)
            .ToList();

        // 创建求助请求记录
        var helpRequest = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = emergencyCallId,
            CircleId = circleId,
            RequesterId = call.ElderId,
            Status = HelpRequestStatus.Pending,
            Latitude = call.Latitude,
            Longitude = call.Longitude,
            RequestedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.Add(_defaultExpiration),
        };

        _context.NeighborHelpRequests.Add(helpRequest);
        await _context.SaveChangesAsync();

        // 记录通知日志（用于后续计算响应率）
        foreach (var neighborId in nearbyUserIds)
        {
            _context.HelpNotificationLogs.Add(new HelpNotificationLog
            {
                Id = Guid.NewGuid(),
                HelpRequestId = helpRequest.Id,
                UserId = neighborId,
                NotifiedAt = DateTime.UtcNow,
            });
        }
        await _context.SaveChangesAsync();

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
            });

        _logger.LogInformation(
            "已广播邻里求助：呼叫={CallId}, 请求={RequestId}, 通知邻居数={Count}",
            emergencyCallId, helpRequest.Id, nearbyUserIds.Count);
    }

    /// <inheritdoc />
    public async Task<NeighborHelpRequestResponse> AcceptHelpRequestAsync(Guid requestId, Guid responderId)
    {
        var request = await _context.NeighborHelpRequests
            .AsTracking()
            .Include(r => r.Requester)
            .FirstOrDefaultAsync(r => r.Id == requestId)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborHelp.RequestNotFound);

        if (request.Status != HelpRequestStatus.Pending)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.InvalidStatus);

        if (request.ExpiresAt < DateTime.UtcNow)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.RequestExpired);

        if (request.RequesterId == responderId)
            throw new ArgumentException(ErrorMessages.NeighborHelp.CannotAcceptOwn);

        // 原子锁定：更新状态和响应者
        request.Status = HelpRequestStatus.Accepted;
        request.ResponderId = responderId;
        request.RespondedAt = DateTime.UtcNow;

        // 更新通知日志：标记该邻居已响应
        var notificationLog = await _context.HelpNotificationLogs
            .AsTracking()
            .FirstOrDefaultAsync(h => h.HelpRequestId == requestId && h.UserId == responderId);
        if (notificationLog != null)
        {
            notificationLog.RespondedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();

        // 查询响应者信息
        var responder = await _context.Users.FindAsync(responderId)
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
            });

        // 通知老人的子女："邻居已响应紧急呼叫"
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == request.RequesterId);
        if (familyMember != null)
        {
            var childIds = await _context.FamilyMembers
                .Where(fm => fm.FamilyId == familyMember.FamilyId && fm.Role == UserRole.Child)
                .Select(fm => fm.UserId)
                .ToListAsync();

            if (childIds.Count > 0)
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
                    });
            }
        }

        // 通知其他邻居："该求助已被接受"
        var otherMemberIds = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == request.CircleId &&
                        m.UserId != responderId &&
                        m.UserId != request.RequesterId)
            .Select(m => m.UserId)
            .ToListAsync();

        if (otherMemberIds.Count > 0)
        {
            await _notificationService.SendToUsersAsync(
                otherMemberIds,
                AppConstants.NotificationTypes.NeighborHelpResolved,
                new
                {
                    Title = NotificationMessages.NeighborHelp.RequestRespondedTitle,
                    Content = string.Format(NotificationMessages.NeighborHelp.RequestAcceptedContentTemplate, request.Requester.RealName, responder.RealName),
                    HelpRequestId = requestId,
                });
        }

        return await BuildHelpRequestResponse(request.Id);
    }

    /// <inheritdoc />
    public async Task CancelHelpRequestAsync(Guid requestId, Guid operatorId)
    {
        var request = await _context.NeighborHelpRequests
            .AsTracking()
            .Include(r => r.Requester)
            .FirstOrDefaultAsync(r => r.Id == requestId)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborHelp.RequestNotFound);

        if (request.Status != HelpRequestStatus.Pending && request.Status != HelpRequestStatus.Accepted)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.InvalidStatus);

        // 验证操作者：老人本人或其子女
        var isRequester = request.RequesterId == operatorId;
        var isChild = false;
        if (!isRequester)
        {
            var familyMember = await _context.FamilyMembers
                .FirstOrDefaultAsync(fm => fm.UserId == request.RequesterId);
            if (familyMember != null)
            {
                isChild = await _context.FamilyMembers
                    .AnyAsync(fm => fm.FamilyId == familyMember.FamilyId &&
                                    fm.UserId == operatorId && fm.Role == UserRole.Child);
            }
        }

        if (!isRequester && !isChild)
            throw new UnauthorizedAccessException(ErrorMessages.NeighborHelp.OnlyRequesterOrChildCancel);

        request.Status = HelpRequestStatus.Cancelled;
        request.CancelledAt = DateTime.UtcNow;
        request.CancelledBy = operatorId;

        // 关闭该请求所有未响应的通知日志
        var pendingLogs = await _context.HelpNotificationLogs
            .AsTracking()
            .Where(h => h.HelpRequestId == requestId && h.RespondedAt == null)
            .ToListAsync();
        foreach (var log in pendingLogs)
        {
            // 设为取消时间表示未响应（保持 RespondedAt 为 null，统计时视为未响应）
            log.RespondedAt = null;
        }

        await _context.SaveChangesAsync();

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
                });
        }

        _logger.LogInformation("求助请求 {RequestId} 已被用户 {OperatorId} 取消", requestId, operatorId);
    }

    /// <inheritdoc />
    public async Task<NeighborHelpRatingResponse> RateHelpRequestAsync(
        Guid requestId, Guid raterId, RateHelpRequest request)
    {
        var helpRequest = await _context.NeighborHelpRequests
            .FirstOrDefaultAsync(r => r.Id == requestId)
            ?? throw new KeyNotFoundException(ErrorMessages.NeighborHelp.RequestNotFound);

        if (helpRequest.Status != HelpRequestStatus.Accepted)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.CanOnlyRateAccepted);

        if (helpRequest.ResponderId == null)
            throw new InvalidOperationException(ErrorMessages.NeighborHelp.NotRespondedCannotRate);

        // 验证评价者：老人本人或其子女
        var isRequester = helpRequest.RequesterId == raterId;
        var isChild = false;
        if (!isRequester)
        {
            var familyMember = await _context.FamilyMembers
                .FirstOrDefaultAsync(fm => fm.UserId == helpRequest.RequesterId);
            if (familyMember != null)
            {
                isChild = await _context.FamilyMembers
                    .AnyAsync(fm => fm.FamilyId == familyMember.FamilyId &&
                                    fm.UserId == raterId && fm.Role == UserRole.Child);
            }
        }

        if (!isRequester && !isChild)
            throw new UnauthorizedAccessException(ErrorMessages.NeighborHelp.OnlyRequesterOrChildRate);

        // 应用层检查：同一用户对同一请求不能重复评价
        if (await _context.NeighborHelpRatings.AnyAsync(r => r.HelpRequestId == requestId && r.RaterId == raterId))
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
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            throw new ArgumentException(ErrorMessages.NeighborHelp.AlreadyRated);
        }

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
    public async Task<List<NeighborHelpRequestResponse>> GetPendingRequestsAsync(Guid userId)
    {
        // 查找用户加入的邻里圈
        var membership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == userId);

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
            .Select(r => new NeighborHelpRequestResponse
            {
                Id = r.Id,
                EmergencyCallId = r.EmergencyCallId,
                CircleId = r.CircleId,
                RequesterId = r.RequesterId,
                RequesterName = r.Requester.RealName,
                ResponderId = r.ResponderId,
                ResponderName = r.Responder != null ? r.Responder.RealName : null,
                Status = r.Status,
                Latitude = r.Latitude,
                Longitude = r.Longitude,
                RequestedAt = r.RequestedAt,
                RespondedAt = r.RespondedAt,
                ExpiresAt = r.ExpiresAt,
            })
            .ToListAsync();
    }

    /// <inheritdoc />
    public async Task<List<NeighborHelpRequestResponse>> GetHistoryAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultHistoryPageSize)
    {
        // 查找用户加入的邻里圈
        var membership = await _context.NeighborCircleMembers
            .FirstOrDefaultAsync(m => m.UserId == userId);

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
            .Select(r => new NeighborHelpRequestResponse
            {
                Id = r.Id,
                EmergencyCallId = r.EmergencyCallId,
                CircleId = r.CircleId,
                RequesterId = r.RequesterId,
                RequesterName = r.Requester.RealName,
                ResponderId = r.ResponderId,
                ResponderName = r.Responder != null ? r.Responder.RealName : null,
                Status = r.Status,
                Latitude = r.Latitude,
                Longitude = r.Longitude,
                RequestedAt = r.RequestedAt,
                RespondedAt = r.RespondedAt,
                ExpiresAt = r.ExpiresAt,
            })
            .ToListAsync();
    }

    /// <inheritdoc />
    public async Task<NeighborHelpRequestResponse> GetRequestAsync(Guid requestId)
    {
        return await BuildHelpRequestResponse(requestId);
    }

    /// <inheritdoc />
    public async Task CleanupExpiredRequestsAsync()
    {
        var now = DateTime.UtcNow;
        var expiredRequests = await _context.NeighborHelpRequests
            .AsTracking()
            .Where(r => r.Status == HelpRequestStatus.Pending && r.ExpiresAt < now)
            .ToListAsync();

        if (expiredRequests.Count == 0)
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
            .ToListAsync();
        // 过期的通知日志保持 RespondedAt 为 null，表示未响应

        await _context.SaveChangesAsync();

        _logger.LogInformation("已清理 {Count} 个过期邻里求助请求", expiredRequests.Count);
    }

    /// <summary>
    /// 无位置信息时，广播给全圈成员
    /// </summary>
    private async Task BroadcastToAllMembersAsync(EmergencyCall call, Guid circleId)
    {
        var memberIds = await _context.NeighborCircleMembers
            .Where(m => m.CircleId == circleId && m.UserId != call.ElderId)
            .Select(m => m.UserId)
            .ToListAsync();

        if (memberIds.Count == 0) return;

        var helpRequest = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = call.Id,
            CircleId = circleId,
            RequesterId = call.ElderId,
            Status = HelpRequestStatus.Pending,
            Latitude = call.Latitude,
            Longitude = call.Longitude,
            RequestedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.Add(_defaultExpiration),
        };

        _context.NeighborHelpRequests.Add(helpRequest);
        await _context.SaveChangesAsync();

        // 记录通知日志
        foreach (var memberId in memberIds)
        {
            _context.HelpNotificationLogs.Add(new HelpNotificationLog
            {
                Id = Guid.NewGuid(),
                HelpRequestId = helpRequest.Id,
                UserId = memberId,
                NotifiedAt = DateTime.UtcNow,
            });
        }
        await _context.SaveChangesAsync();

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
            });
    }

    /// <summary>
    /// 构建求助请求响应
    /// </summary>
    private async Task<NeighborHelpRequestResponse> BuildHelpRequestResponse(Guid requestId)
    {
        var request = await _context.NeighborHelpRequests
            .Include(r => r.Requester)
            .Include(r => r.Responder)
            .FirstAsync(r => r.Id == requestId);

        return new NeighborHelpRequestResponse
        {
            Id = request.Id,
            EmergencyCallId = request.EmergencyCallId,
            CircleId = request.CircleId,
            RequesterId = request.RequesterId,
            RequesterName = request.Requester.RealName,
            ResponderId = request.ResponderId,
            ResponderName = request.Responder?.RealName,
            Status = request.Status,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            RequestedAt = request.RequestedAt,
            RespondedAt = request.RespondedAt,
            ExpiresAt = request.ExpiresAt,
        };
    }
}
