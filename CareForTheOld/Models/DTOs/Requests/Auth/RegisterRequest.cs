using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Validators;
using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Auth;

/// <summary>
/// 注册请求 DTO
/// </summary>
public class RegisterRequest
{
    [Required(ErrorMessage = ValidationMessages.Auth.PhoneRequired)]
    [RegularExpression(@"^1[3-9]\d{9}$", ErrorMessage = ValidationMessages.Auth.PhoneInvalid)]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = ValidationMessages.Auth.PasswordRequired)]
    [PasswordValidator]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = ValidationMessages.Auth.NameRequired)]
    [StringLength(50, ErrorMessage = ValidationMessages.Auth.NameTooLong)]
    public string RealName { get; set; } = string.Empty;

    [Required(ErrorMessage = ValidationMessages.Auth.BirthDateRequired)]
    public DateOnly BirthDate { get; set; }

    [Required(ErrorMessage = ValidationMessages.Auth.RoleRequired)]
    [EnumDataType(typeof(UserRole), ErrorMessage = ValidationMessages.Auth.RoleInvalid)]
    public UserRole Role { get; set; }
}