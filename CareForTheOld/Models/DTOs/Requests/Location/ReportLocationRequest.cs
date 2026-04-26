using CareForTheOld.Common.Constants;
using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace CareForTheOld.Models.DTOs.Requests.Location;

/// <summary>
/// 上报位置请求
/// </summary>
public class ReportLocationRequest
{
    /// <summary>
    /// 纬度（-90 到 90，最多 6 位小数）
    /// </summary>
    [Required(ErrorMessage = ValidationMessages.Location.LatitudeRequired)]
    [Range(-90.0, 90.0, ErrorMessage = ValidationMessages.Location.LatitudeOutOfRange)]
    public double Latitude { get; set; }

    /// <summary>
    /// 经度（-180 到 180，最多 6 位小数）
    /// </summary>
    [Required(ErrorMessage = ValidationMessages.Location.LongitudeRequired)]
    [Range(-180.0, 180.0, ErrorMessage = ValidationMessages.Location.LongitudeOutOfRange)]
    public double Longitude { get; set; }

    /// <summary>
    /// GPS 定位精度（米），用于过滤低精度飘移数据
    /// 精度超过 100 米时跳过电子围栏判断，防止室内 GPS 飘移触发误报
    /// </summary>
    [Range(0.0, 10000.0, ErrorMessage = ValidationMessages.Location.AccuracyOutOfRange)]
    public double? Accuracy { get; set; }
}