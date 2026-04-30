using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Emergency;

/// <summary>
/// 发起紧急呼叫请求
/// </summary>
public class CreateEmergencyCallRequest
{
    /// <summary>
    /// 纬度（可选，前端获取 GPS 后上报）
    /// </summary>
    [Range(-90, 90, ErrorMessage = "纬度必须在 -90 到 90 之间")]
    public double? Latitude { get; set; }

    /// <summary>
    /// 经度（可选，前端获取 GPS 后上报）
    /// </summary>
    [Range(-180, 180, ErrorMessage = "经度必须在 -180 到 180 之间")]
    public double? Longitude { get; set; }

    /// <summary>
    /// 电池电量百分比（可选，0~100）
    /// </summary>
    [Range(0, 100, ErrorMessage = "电池电量必须在 0-100 之间")]
    public int? BatteryLevel { get; set; }
}
