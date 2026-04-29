namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>认证响应（登录/注册/刷新令牌）</summary>
public class AuthResponse
{
    /// <summary>访问令牌</summary>
    public string AccessToken { get; set; } = string.Empty;
    /// <summary>刷新令牌</summary>
    public string RefreshToken { get; set; } = string.Empty;
    /// <summary>令牌过期时间</summary>
    public DateTime ExpiresAt { get; set; }
    /// <summary>用户信息</summary>
    public UserResponse User { get; set; } = null!;
}