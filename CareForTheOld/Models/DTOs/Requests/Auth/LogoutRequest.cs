using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Auth;

/// <summary>
/// 登出请求
/// </summary>
public class LogoutRequest
{
    /// <summary>刷新令牌（可选，传入时一并吊销）</summary>
    [StringLength(500)]
    public string? RefreshToken { get; set; }
}
