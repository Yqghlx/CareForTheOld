using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Location;

/// <summary>
/// 上报位置请求
/// </summary>
public class ReportLocationRequest
{
    /// <summary>
    /// 纬度（-90 到 90）
    /// </summary>
    [Required(ErrorMessage = "纬度不能为空")]
    [Range(-90.0, 90.0, ErrorMessage = "纬度范围应在 -90 到 90 之间")]
    public double Latitude { get; set; }

    /// <summary>
    /// 经度（-180 到 180）
    /// </summary>
    [Required(ErrorMessage = "经度不能为空")]
    [Range(-180.0, 180.0, ErrorMessage = "经度范围应在 -180 到 180 之间")]
    public double Longitude { get; set; }
}