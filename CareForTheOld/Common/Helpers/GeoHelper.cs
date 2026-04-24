namespace CareForTheOld.Common.Helpers;

/// <summary>
/// 地理位置计算工具类，提供经纬度相关的通用计算方法
/// </summary>
public static class GeoHelper
{
    /// <summary>
    /// 地球平均半径（米），用于球面距离计算
    /// </summary>
    private const double EarthRadiusMeters = 6_371_000;

    /// <summary>
    /// 使用 Haversine 公式计算两个经纬度坐标之间的球面距离
    /// </summary>
    /// <param name="lat1">起点纬度</param>
    /// <param name="lon1">起点经度</param>
    /// <param name="lat2">终点纬度</param>
    /// <param name="lon2">终点经度</param>
    /// <returns>两点之间的球面距离（米）</returns>
    public static double HaversineDistance(double lat1, double lon1, double lat2, double lon2)
    {
        var dLat = (lat2 - lat1) * Math.PI / 180.0;
        var dLon = (lon2 - lon1) * Math.PI / 180.0;
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(lat1 * Math.PI / 180.0) * Math.Cos(lat2 * Math.PI / 180.0) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return EarthRadiusMeters * c;
    }
}
