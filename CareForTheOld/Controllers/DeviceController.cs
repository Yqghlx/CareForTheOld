using System.ComponentModel.DataAnnotations;
using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

/// <summary>
/// 设备管理控制器
///
/// 管理用户设备的 FCM 推送令牌。
/// 登录后注册 token 以接收推送通知，登出时清除。
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class DeviceController : ControllerBase
{
    private readonly IDeviceService _deviceService;

    public DeviceController(IDeviceService deviceService)
    {
        _deviceService = deviceService;
    }

    /// <summary>
    /// 注册或刷新 FCM 设备令牌
    ///
    /// 登录成功后调用此接口将 FCM token 关联到当前用户。
    /// 若 token 已存在（同一设备换用户登录），则更新关联用户和活跃时间。
    /// </summary>
    [HttpPost("token")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ApiResponse<object>> RegisterToken([FromBody] RegisterTokenRequest request, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _deviceService.RegisterTokenAsync(userId, request.Token, request.Platform, cancellationToken);
        return ApiResponse<object>.Ok(null!, SuccessMessages.Device.TokenRegistered);
    }

    /// <summary>
    /// 清除当前用户的所有设备令牌（登出时调用）
    /// </summary>
    [HttpDelete("token")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ApiResponse<object>> DeleteToken(CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _deviceService.DeleteTokensAsync(userId, cancellationToken);
        return ApiResponse<object>.Ok(null!, SuccessMessages.Device.TokenCleared);
    }
}

/// <summary>
/// 注册设备令牌请求
/// </summary>
public class RegisterTokenRequest
{
    /// <summary>
    /// FCM 设备令牌
    /// </summary>
    [Required(ErrorMessage = ErrorMessages.Device.TokenRequired)]
    [MaxLength(512, ErrorMessage = ErrorMessages.Device.TokenTooLong)]
    public string Token { get; set; } = string.Empty;

    /// <summary>
    /// 平台标识（"android" / "ios"）
    /// </summary>
    [MaxLength(20)]
    public string Platform { get; set; } = AppConstants.DevicePlatforms.Android;
}
