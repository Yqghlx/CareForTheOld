using CareForTheOld.Common.Constants;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Auth;

/// <summary>
/// 登录请求 DTO
/// </summary>
public class LoginRequest
{
    [Required(ErrorMessage = ValidationMessages.Auth.PhoneRequired)]
    [StringLength(11, MinimumLength = 11, ErrorMessage = ValidationMessages.Auth.PhoneInvalid)]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = ValidationMessages.Auth.PasswordRequired)]
    [StringLength(100, ErrorMessage = ValidationMessages.Auth.PasswordTooLong)]
    public string Password { get; set; } = string.Empty;
}
