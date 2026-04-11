using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.Entities;

/// <summary>
/// 用户实体
/// </summary>
public class User
{
    public Guid Id { get; set; }
    public string PhoneNumber { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string RealName { get; set; } = string.Empty;
    public DateOnly BirthDate { get; set; }
    public UserRole Role { get; set; }
    public string? AvatarUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public ICollection<FamilyMember> FamilyMemberships { get; set; } = [];
    public ICollection<HealthRecord> HealthRecords { get; set; } = [];
    public ICollection<MedicationPlan> MedicationPlans { get; set; } = [];
    public ICollection<RefreshToken> RefreshTokens { get; set; } = [];
}