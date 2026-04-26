using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Auth;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

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
    public async Task<ApiResponse<AuthResponse>> Register([FromBody] RegisterRequest request)
    {
        var result = await _authService.RegisterAsync(request);
        return ApiResponse<AuthResponse>.Ok(result, SuccessMessages.Auth.RegisterSuccess);
    }

    /// <summary>用户登录</summary>
    [HttpPost("login")]
    public async Task<ApiResponse<AuthResponse>> Login([FromBody] LoginRequest request)
    {
        var result = await _authService.LoginAsync(request);
        return ApiResponse<AuthResponse>.Ok(result, SuccessMessages.Auth.LoginSuccess);
    }

    /// <summary>刷新令牌</summary>
    [HttpPost("refresh")]
    public async Task<ApiResponse<AuthResponse>> Refresh([FromBody] RefreshTokenRequest request)
    {
        var result = await _authService.RefreshTokenAsync(request.RefreshToken);
        return ApiResponse<AuthResponse>.Ok(result, SuccessMessages.Auth.RefreshSuccess);
    }
}