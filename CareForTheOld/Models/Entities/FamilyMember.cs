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

    // 导航属性
    public Family Family { get; set; } = null!;
    public User User { get; set; } = null!;
}