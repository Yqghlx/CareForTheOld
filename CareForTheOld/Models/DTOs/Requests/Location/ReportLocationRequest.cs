namespace CareForTheOld.Models.DTOs.Requests.Location;

/// <summary>
/// 上报位置请求
/// </summary>
public class ReportLocationRequest
{
    /// <summary>
    /// 纬度
    /// </summary>
    public double Latitude { get; set; }

    /// <summary>
    /// 经度
    /// </summary>
    public double Longitude { get; set; }
}