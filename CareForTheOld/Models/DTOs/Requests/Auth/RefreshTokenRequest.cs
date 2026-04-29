using CareForTheOld.Common.Constants;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Auth;

/// <summary>
/// 刷新令牌请求 DTO
/// </summary>
public class RefreshTokenRequest
{
    [Required(ErrorMessage = ValidationMessages.Auth.RefreshTokenRequired)]
    [StringLength(500, ErrorMessage = ValidationMessages.Auth.RefreshTokenTooLong)]
    public string RefreshToken { get; set; } = string.Empty;
}
