namespace CareForTheOld.Models.Enums;

/// <summary>
/// RescueTriggerType 枚举扩展方法
/// </summary>
public static class RescueTriggerTypeExtensions
{
    /// <summary>
    /// 获取触发类型的中文标签
    /// </summary>
    public static string GetLabel(this RescueTriggerType type) => type switch
    {
        RescueTriggerType.GeoFenceBreach => "地理围栏越界",
        RescueTriggerType.HeartbeatTimeout => "心跳超时",
        _ => type.ToString()
    };
}
