using CareForTheOld.Models.DTOs.Requests.Auth;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 认证服务接口
/// </summary>
public interface IAuthService
{
    /// <summary>用户注册</summary>
    Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default);

    /// <summary>用户登录</summary>
    Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default);

    /// <summary>刷新令牌</summary>
    Task<AuthResponse> RefreshTokenAsync(string refreshToken, CancellationToken cancellationToken = default);

    /// <summary>登出：将 AccessToken 加入黑名单并吊销 RefreshToken</summary>
    Task LogoutAsync(string accessToken, string? refreshToken, CancellationToken cancellationToken = default);

    /// <summary>吊销用户的所有令牌（密码修改、安全事件时调用）</summary>
    Task RevokeAllUserTokensAsync(Guid userId, CancellationToken cancellationToken = default);
}