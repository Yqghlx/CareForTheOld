using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>家庭组响应</summary>
public class FamilyResponse
{
    /// <summary>家庭组ID</summary>
    public Guid Id { get; set; }
    /// <summary>家庭组名称</summary>
    public string FamilyName { get; set; } = string.Empty;
    /// <summary>邀请码</summary>
    public string InviteCode { get; set; } = string.Empty;
    /// <summary>邀请码过期时间</summary>
    public DateTime? InviteCodeExpiresAt { get; set; }
    /// <summary>家庭成员列表</summary>
    public List<FamilyMemberResponse> Members { get; set; } = [];
}

/// <summary>家庭成员响应</summary>
public class FamilyMemberResponse
{
    /// <summary>用户ID</summary>
    public Guid UserId { get; set; }
    /// <summary>真实姓名</summary>
    public string RealName { get; set; } = string.Empty;
    /// <summary>用户角色</summary>
    public UserRole Role { get; set; }
    /// <summary>与老人的关系</summary>
    public string Relation { get; set; } = string.Empty;
    /// <summary>头像URL</summary>
    public string? AvatarUrl { get; set; }

    /// <summary>
    /// 成员状态（Pending=待审批, Approved=已通过）
    /// </summary>
    public FamilyMemberStatus Status { get; set; }
}