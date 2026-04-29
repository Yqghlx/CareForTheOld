using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>邻里圈响应</summary>
public class NeighborCircleResponse
{
    /// <summary>邻里圈ID</summary>
    public Guid Id { get; set; }
    /// <summary>圈子名称</summary>
    public string CircleName { get; set; } = string.Empty;
    /// <summary>中心纬度</summary>
    public double CenterLatitude { get; set; }
    /// <summary>中心经度</summary>
    public double CenterLongitude { get; set; }
    /// <summary>覆盖半径（米）</summary>
    public double RadiusMeters { get; set; }
    /// <summary>创建者ID</summary>
    public Guid CreatorId { get; set; }
    /// <summary>创建者姓名</summary>
    public string CreatorName { get; set; } = string.Empty;
    /// <summary>邀请码</summary>
    public string InviteCode { get; set; } = string.Empty;
    /// <summary>邀请码过期时间</summary>
    public DateTime? InviteCodeExpiresAt { get; set; }
    /// <summary>成员数量</summary>
    public int MemberCount { get; set; }
    /// <summary>是否激活</summary>
    public bool IsActive { get; set; }
    /// <summary>创建时间</summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>距当前位置的距离（米），搜索附近时使用</summary>
    public double? DistanceMeters { get; set; }
}

/// <summary>邻里成员响应</summary>
public class NeighborMemberResponse
{
    /// <summary>用户ID</summary>
    public Guid UserId { get; set; }
    /// <summary>真实姓名</summary>
    public string RealName { get; set; } = string.Empty;
    /// <summary>成员角色</summary>
    public UserRole Role { get; set; }
    /// <summary>昵称</summary>
    public string? Nickname { get; set; }
    /// <summary>头像URL</summary>
    public string? AvatarUrl { get; set; }
    /// <summary>加入时间</summary>
    public DateTime JoinedAt { get; set; }

    /// <summary>距指定位置的距离（米）</summary>
    public double? DistanceMeters { get; set; }
}

/// <summary>求助请求响应</summary>
public class NeighborHelpRequestResponse
{
    /// <summary>请求ID</summary>
    public Guid Id { get; set; }
    /// <summary>关联的紧急呼叫ID</summary>
    public Guid EmergencyCallId { get; set; }
    /// <summary>所属邻里圈ID</summary>
    public Guid CircleId { get; set; }
    /// <summary>求助者ID</summary>
    public Guid RequesterId { get; set; }
    /// <summary>求助者姓名</summary>
    public string RequesterName { get; set; } = string.Empty;
    /// <summary>响应者ID，可空</summary>
    public Guid? ResponderId { get; set; }
    /// <summary>响应者姓名，可空</summary>
    public string? ResponderName { get; set; }
    /// <summary>求助状态</summary>
    public HelpRequestStatus Status { get; set; }
    /// <summary>纬度，可空</summary>
    public double? Latitude { get; set; }
    /// <summary>经度，可空</summary>
    public double? Longitude { get; set; }
    /// <summary>请求时间</summary>
    public DateTime RequestedAt { get; set; }
    /// <summary>响应时间，可空</summary>
    public DateTime? RespondedAt { get; set; }
    /// <summary>过期时间</summary>
    public DateTime ExpiresAt { get; set; }

    /// <summary>距当前位置的距离（米）</summary>
    public double? DistanceMeters { get; set; }
}

/// <summary>互助评价响应</summary>
public class NeighborHelpRatingResponse
{
    /// <summary>评价ID</summary>
    public Guid Id { get; set; }
    /// <summary>关联的求助请求ID</summary>
    public Guid HelpRequestId { get; set; }
    /// <summary>评价者ID</summary>
    public Guid RaterId { get; set; }
    /// <summary>被评价者ID</summary>
    public Guid RateeId { get; set; }
    /// <summary>评分（1~5）</summary>
    public int Rating { get; set; }
    /// <summary>评价内容，可空</summary>
    public string? Comment { get; set; }
    /// <summary>创建时间</summary>
    public DateTime CreatedAt { get; set; }
}
