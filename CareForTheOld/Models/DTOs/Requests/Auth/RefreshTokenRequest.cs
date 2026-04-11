using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Auth;

/// <summary>
/// 刷新令牌请求 DTO
/// </summary>
public class RefreshTokenRequest
{
    [Required(ErrorMessage = "刷新令牌不能为空")]
    public string RefreshToken { get; set; } = string.Empty;
}