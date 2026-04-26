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

    /// <summary>
    /// 计算给定半径对应的经纬度度数阈值，用于粗筛过滤远距离坐标
    /// 纬度方向 1° ≈ 111km，经度方向受纬度影响（赤道 111km → 极地趋近 0）
    /// </summary>
    /// <param name="radiusMeters">半径（米）</param>
    /// <param name="latitude">中心点纬度，用于修正经度阈值</param>
    /// <returns>纬度阈值和经度阈值（单位：度）</returns>
    public static (double LatThreshold, double LngThreshold) CalculateDegreeThresholds(double radiusMeters, double latitude)
    {
        var latThreshold = radiusMeters / 111_000.0;
        var lngThreshold = radiusMeters / (111_000.0 * Math.Cos(latitude * Math.PI / 180.0));
        return (latThreshold, lngThreshold);
    }
}
