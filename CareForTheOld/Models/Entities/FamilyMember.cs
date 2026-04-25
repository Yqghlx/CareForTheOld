using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 家庭成员关系实体（中间表）
/// </summary>
public class FamilyMember
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid UserId { get; set; }
    public UserRole Role { get; set; }
    public string Relation { get; set; } = string.Empty;

    /// <summary>
    /// 成员状态（Pending=待审批, Approved=已通过, Rejected=已拒绝）
    /// 创建者直接加入时为 Approved，通过邀请码加入时先为 Pending 待审批
    /// </summary>
    public FamilyMemberStatus Status { get; set; } = FamilyMemberStatus.Approved;

    // 导航属性
    public Family Family { get; set; } = null!;
    public User User { get; set; } = null!;
}