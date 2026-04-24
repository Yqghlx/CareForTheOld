using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>邻里圈响应</summary>
public class NeighborCircleResponse
{
    public Guid Id { get; set; }
    public string CircleName { get; set; } = string.Empty;
    public double CenterLatitude { get; set; }
    public double CenterLongitude { get; set; }
    public double RadiusMeters { get; set; }
    public Guid CreatorId { get; set; }
    public string CreatorName { get; set; } = string.Empty;
    public string InviteCode { get; set; } = string.Empty;
    public DateTime? InviteCodeExpiresAt { get; set; }
    public int MemberCount { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }

    /// <summary>距当前位置的距离（米），搜索附近时使用</summary>
    public double? DistanceMeters { get; set; }
}

/// <summary>邻里圈成员响应</summary>
public class NeighborMemberResponse
{
    public Guid UserId { get; set; }
    public string RealName { get; set; } = string.Empty;
    public UserRole Role { get; set; }
    public string? Nickname { get; set; }
    public string? AvatarUrl { get; set; }
    public DateTime JoinedAt { get; set; }

    /// <summary>距指定位置的距离（米）</summary>
    public double? DistanceMeters { get; set; }
}

/// <summary>邻里求助请求响应</summary>
public class NeighborHelpRequestResponse
{
    public Guid Id { get; set; }
    public Guid EmergencyCallId { get; set; }
    public Guid CircleId { get; set; }
    public Guid RequesterId { get; set; }
    public string RequesterName { get; set; } = string.Empty;
    public Guid? ResponderId { get; set; }
    public string? ResponderName { get; set; }
    public HelpRequestStatus Status { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public DateTime RequestedAt { get; set; }
    public DateTime? RespondedAt { get; set; }
    public DateTime ExpiresAt { get; set; }

    /// <summary>距当前位置的距离（米）</summary>
    public double? DistanceMeters { get; set; }
}

/// <summary>邻里互助评价响应</summary>
public class NeighborHelpRatingResponse
{
    public Guid Id { get; set; }
    public Guid HelpRequestId { get; set; }
    public Guid RaterId { get; set; }
    public Guid RateeId { get; set; }
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAt { get; set; }
}
