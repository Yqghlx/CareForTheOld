namespace CareForTheOld.Models.Enums;

/// <summary>
/// AutoRescueStatus 枚举扩展方法
/// </summary>
public static class AutoRescueStatusExtensions
{
    /// <summary>
    /// 获取救援状态的中文标签
    /// </summary>
    public static string GetLabel(this AutoRescueStatus status) => status switch
    {
        AutoRescueStatus.WaitingChildResponse => "等待子女响应",
        AutoRescueStatus.ChildResponded => "子女已响应",
        AutoRescueStatus.NeighborBroadcast => "已触发邻里广播",
        AutoRescueStatus.Resolved => "已解决",
        _ => status.ToString()
    };
}
