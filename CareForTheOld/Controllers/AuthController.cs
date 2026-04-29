using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Auth;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

/// <summary>
/// 认证控制器
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[EnableRateLimiting("AuthPolicy")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    /// <summary>用户注册</summary>
    [HttpPost("register")]
    [ProducesResponseType(typeof(ApiResponse<AuthResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    public async Task<ApiResponse<AuthResponse>> Register([FromBody] RegisterRequest request, CancellationToken cancellationToken = default)
    {
        var result = await _authService.RegisterAsync(request, cancellationToken);
        return ApiResponse<AuthResponse>.Ok(result, SuccessMessages.Auth.RegisterSuccess);
    }

    /// <summary>用户登录</summary>
    [HttpPost("login")]
    [ProducesResponseType(typeof(ApiResponse<AuthResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    public async Task<ApiResponse<AuthResponse>> Login([FromBody] LoginRequest request, CancellationToken cancellationToken = default)
    {
        var result = await _authService.LoginAsync(request, cancellationToken);
        return ApiResponse<AuthResponse>.Ok(result, SuccessMessages.Auth.LoginSuccess);
    }

    /// <summary>刷新令牌</summary>
    [HttpPost("refresh")]
    [ProducesResponseType(typeof(ApiResponse<AuthResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    public async Task<ApiResponse<AuthResponse>> Refresh([FromBody] RefreshTokenRequest request, CancellationToken cancellationToken = default)
    {
        var result = await _authService.RefreshTokenAsync(request.RefreshToken, cancellationToken);
        return ApiResponse<AuthResponse>.Ok(result, SuccessMessages.Auth.RefreshSuccess);
    }

    /// <summary>用户登出：吊销当前令牌</summary>
    [HttpPost("logout")]
    [Microsoft.AspNetCore.Authorization.Authorize]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ApiResponse<object>> Logout([FromBody] LogoutRequest? request, CancellationToken cancellationToken = default)
    {
        // 从 Authorization Header 提取 AccessToken
        var accessToken = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "").Trim();

        if (!string.IsNullOrEmpty(accessToken))
        {
            await _authService.LogoutAsync(accessToken, request?.RefreshToken, cancellationToken);
        }

        return ApiResponse<object>.Ok(SuccessMessages.Auth.LogoutSuccess);
    }
}