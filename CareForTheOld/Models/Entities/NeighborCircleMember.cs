using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 邻里圈成员关系实体
/// </summary>
public class NeighborCircleMember
{
    public Guid Id { get; set; }
    public Guid CircleId { get; set; }
    public Guid UserId { get; set; }
    public UserRole Role { get; set; }
    public NeighborCircleStatus Status { get; set; } = NeighborCircleStatus.Approved;

    /// <summary>圈内昵称（可选）</summary>
    public string? Nickname { get; set; }

    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public NeighborCircle Circle { get; set; } = null!;
    public User User { get; set; } = null!;
}
