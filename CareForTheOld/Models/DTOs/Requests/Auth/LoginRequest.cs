using CareForTheOld.Common.Constants;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Auth;

/// <summary>
/// 登录请求 DTO
/// </summary>
public class LoginRequest
{
    [Required(ErrorMessage = ValidationMessages.Auth.PhoneRequired)]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = ValidationMessages.Auth.PasswordRequired)]
    public string Password { get; set; } = string.Empty;
}