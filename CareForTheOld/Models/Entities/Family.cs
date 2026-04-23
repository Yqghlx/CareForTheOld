namespace CareForTheOld.Models.Entities;

/// <summary>
/// 家庭组实体
/// </summary>
public class Family
{
    public Guid Id { get; set; }
    public string FamilyName { get; set; } = string.Empty;
    public Guid CreatorId { get; set; }
    public string InviteCode { get; set; } = string.Empty;
    /// <summary>邀请码过期时间（默认7天）</summary>
    public DateTime? InviteCodeExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public User Creator { get; set; } = null!;
    public ICollection<FamilyMember> Members { get; set; } = [];
}