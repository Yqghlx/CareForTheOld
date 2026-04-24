namespace CareForTheOld.Models.Enums;

/// <summary>
/// 自动救援状态
/// </summary>
public enum AutoRescueStatus
{
    /// <summary>等待子女响应</summary>
    WaitingChildResponse = 0,

    /// <summary>子女已响应</summary>
    ChildResponded = 1,

    /// <summary>已触发邻里广播</summary>
    NeighborBroadcast = 2,

    /// <summary>已解决</summary>
    Resolved = 3,
}
