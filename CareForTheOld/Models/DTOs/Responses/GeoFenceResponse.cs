namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 电子围栏响应
/// </summary>
public class GeoFenceResponse
{
    public Guid Id { get; set; }

    /// <summary>
    /// 监控的老人用户ID
    /// </summary>
    public Guid ElderId { get; set; }

    /// <summary>
    /// 老人姓名
    /// </summary>
    public string? ElderName { get; set; }

    /// <summary>
    /// 围栏中心纬度
    /// </summary>
    public double CenterLatitude { get; set; }

    /// <summary>
    /// 围栏中心经度
    /// </summary>
    public double CenterLongitude { get; set; }

    /// <summary>
    /// 围栏半径（米）
    /// </summary>
    public int Radius { get; set; }

    /// <summary>
    /// 是否启用
    /// </summary>
    public bool IsEnabled { get; set; }

    /// <summary>
    /// 创建者用户ID
    /// </summary>
    public Guid CreatedBy { get; set; }

    /// <summary>
    /// 创建时间
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// 更新时间
    /// </summary>
    public DateTime UpdatedAt { get; set; }
}