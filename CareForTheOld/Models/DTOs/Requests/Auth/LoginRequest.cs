using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Auth;

/// <summary>
/// 登录请求 DTO
/// </summary>
public class LoginRequest
{
    [Required(ErrorMessage = "手机号不能为空")]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = "密码不能为空")]
    public string Password { get; set; } = string.Empty;
}