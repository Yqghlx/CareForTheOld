using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Auth;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace CareForTheOld.Controllers;

/// <summary>
/// 认证控制器
/// </summary>
[ApiController]
[Route("api/[controller]")]
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
        return ApiResponse<AuthResponse>.Ok(result, "注册成功");
    }

    /// <summary>用户登录</summary>
    [HttpPost("login")]
    public async Task<ApiResponse<AuthResponse>> Login([FromBody] LoginRequest request)
    {
        var result = await _authService.LoginAsync(request);
        return ApiResponse<AuthResponse>.Ok(result, "登录成功");
    }

    /// <summary>刷新令牌</summary>
    [HttpPost("refresh")]
    public async Task<ApiResponse<AuthResponse>> Refresh([FromBody] RefreshTokenRequest request)
    {
        var result = await _authService.RefreshTokenAsync(request.RefreshToken);
        return ApiResponse<AuthResponse>.Ok(result, "刷新成功");
    }
}