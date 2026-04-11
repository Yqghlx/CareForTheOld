using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 用户响应 DTO
/// </summary>
public class UserResponse
{
    public Guid Id { get; set; }
    public string PhoneNumber { get; set; } = string.Empty;
    public string RealName { get; set; } = string.Empty;
    public DateOnly BirthDate { get; set; }
    public UserRole Role { get; set; }
    public string? AvatarUrl { get; set; }
}