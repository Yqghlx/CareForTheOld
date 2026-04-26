using CareForTheOld.Common.Constants;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 电子围栏（安全区域）实体
/// </summary>
public class GeoFence
{
    public Guid Id { get; set; }

    /// <summary>
    /// 监控的老人用户ID
    /// </summary>
    public Guid ElderId { get; set; }

    /// <summary>
    /// 围栏中心纬度
    /// </summary>
    public double CenterLatitude { get; set; }

    /// <summary>
    /// 围栏中心经度
    /// </summary>
    public double CenterLongitude { get; set; }

    /// <summary>
    /// 围栏半径（米），默认500米
    /// </summary>
    public int Radius { get; set; } = AppConstants.GeoFence.DefaultRadiusMeters;

    /// <summary>
    /// 是否启用
    /// </summary>
    public bool IsEnabled { get; set; } = true;

    /// <summary>
    /// 创建者用户ID（子女）
    /// </summary>
    public Guid CreatedBy { get; set; }

    /// <summary>
    /// 创建时间
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 更新时间
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public User Elder { get; set; } = null!;
    public User Creator { get; set; } = null!;
}