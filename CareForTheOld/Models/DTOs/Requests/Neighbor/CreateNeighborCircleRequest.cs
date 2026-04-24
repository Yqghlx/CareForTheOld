using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Neighbor;

/// <summary>
/// 创建邻里圈请求
/// </summary>
public class CreateNeighborCircleRequest
{
    /// <summary>邻里圈名称</summary>
    [Required, MaxLength(100)]
    public string CircleName { get; set; } = string.Empty;

    /// <summary>中心点纬度</summary>
    [Required, Range(-90.0, 90.0)]
    public double CenterLatitude { get; set; }

    /// <summary>中心点经度</summary>
    [Required, Range(-180.0, 180.0)]
    public double CenterLongitude { get; set; }

    /// <summary>覆盖半径（米），默认 500</summary>
    [Range(100, 2000)]
    public double RadiusMeters { get; set; } = 500;
}
