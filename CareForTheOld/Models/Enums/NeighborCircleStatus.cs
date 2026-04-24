namespace CareForTheOld.Models.Enums;

/// <summary>
/// 邻里圈成员状态
/// </summary>
public enum NeighborCircleStatus
{
    /// <summary>申请中</summary>
    Pending = 0,

    /// <summary>已通过</summary>
    Approved = 1,

    /// <summary>已拒绝/已退出</summary>
    Rejected = 2,
}
