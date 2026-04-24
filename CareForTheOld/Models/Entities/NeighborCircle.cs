namespace CareForTheOld.Models.Entities;

/// <summary>
/// 邻里圈实体（基于地理位置的互助社区）
/// </summary>
public class NeighborCircle
{
    public Guid Id { get; set; }
    public string CircleName { get; set; } = string.Empty;

    /// <summary>中心点纬度</summary>
    public double CenterLatitude { get; set; }

    /// <summary>中心点经度</summary>
    public double CenterLongitude { get; set; }

    /// <summary>覆盖半径（米），默认 500</summary>
    public double RadiusMeters { get; set; } = 500;

    public Guid CreatorId { get; set; }

    /// <summary>6 位数字邀请码</summary>
    public string InviteCode { get; set; } = string.Empty;

    /// <summary>邀请码过期时间（默认 7 天）</summary>
    public DateTime? InviteCodeExpiresAt { get; set; }

    /// <summary>最大成员数，默认 50</summary>
    public int MaxMembers { get; set; } = 50;

    /// <summary>是否启用（创建者退出时设为 false）</summary>
    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public User Creator { get; set; } = null!;
    public ICollection<NeighborCircleMember> Members { get; set; } = [];
}
