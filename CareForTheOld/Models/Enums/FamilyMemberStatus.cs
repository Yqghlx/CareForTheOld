namespace CareForTheOld.Models.Enums;

/// <summary>
/// 家庭成员状态（用于加入审批流程）
/// </summary>
public enum FamilyMemberStatus
{
    /// <summary>
    /// 待审批
    /// </summary>
    Pending = 0,

    /// <summary>
    /// 已通过
    /// </summary>
    Approved = 1,

    /// <summary>
    /// 已拒绝
    /// </summary>
    Rejected = 2
}
