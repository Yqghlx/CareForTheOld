using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.GeoFences;

/// <summary>
/// 创建电子围栏请求
/// </summary>
public class CreateGeoFenceRequest
{
    /// <summary>
    /// 监控的老人用户ID
    /// </summary>
    [Required]
    public Guid ElderId { get; set; }

    /// <summary>
    /// 围栏中心纬度
    /// </summary>
    [Required]
    [Range(-90, 90)]
    public double CenterLatitude { get; set; }

    /// <summary>
    /// 围栏中心经度
    /// </summary>
    [Required]
    [Range(-180, 180)]
    public double CenterLongitude { get; set; }

    /// <summary>
    /// 围栏半径（米），默认500米
    /// </summary>
    [Range(50, 5000)]
    public int Radius { get; set; } = 500;

    /// <summary>
    /// 是否启用，默认启用
    /// </summary>
    public bool IsEnabled { get; set; } = true;
}