namespace CareForTheOld.Models.Enums;

/// <summary>
/// 自动救援触发类型
/// </summary>
public enum RescueTriggerType
{
    /// <summary>地理围栏越界</summary>
    GeoFenceBreach = 0,

    /// <summary>心跳超时（设备离线）</summary>
    HeartbeatTimeout = 1,
}
