using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Auth;

/// <summary>
/// 注册请求 DTO
/// </summary>
public class RegisterRequest
{
    [Required(ErrorMessage = "手机号不能为空")]
    [Phone(ErrorMessage = "手机号格式不正确")]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = "密码不能为空")]
    [StringLength(100, MinimumLength = 6, ErrorMessage = "密码长度至少6位")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "姓名不能为空")]
    [StringLength(50, ErrorMessage = "姓名长度不能超过50")]
    public string RealName { get; set; } = string.Empty;

    [Required(ErrorMessage = "出生日期不能为空")]
    public DateOnly BirthDate { get; set; }

    [Required(ErrorMessage = "角色不能为空")]
    public UserRole Role { get; set; }
}