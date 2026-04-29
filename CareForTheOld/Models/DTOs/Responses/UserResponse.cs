using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>用户信息响应</summary>
public class UserResponse
{
    /// <summary>用户ID</summary>
    public Guid Id { get; set; }
    /// <summary>手机号</summary>
    public string PhoneNumber { get; set; } = string.Empty;
    /// <summary>真实姓名</summary>
    public string RealName { get; set; } = string.Empty;
    /// <summary>出生日期</summary>
    public DateOnly BirthDate { get; set; }
    /// <summary>用户角色</summary>
    public UserRole Role { get; set; }
    /// <summary>头像URL</summary>
    public string? AvatarUrl { get; set; }
}