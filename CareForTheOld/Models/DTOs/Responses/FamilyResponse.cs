using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

public class FamilyResponse
{
    public Guid Id { get; set; }
    public string FamilyName { get; set; } = string.Empty;
    public string InviteCode { get; set; } = string.Empty;
    /// <summary>邀请码过期时间</summary>
    public DateTime? InviteCodeExpiresAt { get; set; }
    public List<FamilyMemberResponse> Members { get; set; } = [];
}

public class FamilyMemberResponse
{
    public Guid UserId { get; set; }
    public string RealName { get; set; } = string.Empty;
    public UserRole Role { get; set; }
    public string Relation { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
}