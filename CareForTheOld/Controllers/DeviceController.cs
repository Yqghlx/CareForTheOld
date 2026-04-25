using System.ComponentModel.DataAnnotations;
using Asp.Versioning;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Data;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

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
    private readonly AppDbContext _context;
    private readonly ILogger<DeviceController> _logger;

    public DeviceController(AppDbContext context, ILogger<DeviceController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// 注册或刷新 FCM 设备令牌
    ///
    /// 登录成功后调用此接口将 FCM token 关联到当前用户。
    /// 若 token 已存在（同一设备换用户登录），则更新关联用户和活跃时间。
    /// </summary>
    [HttpPost("token")]
    public async Task<ApiResponse<object>> RegisterToken([FromBody] RegisterTokenRequest request)
    {
        var userId = this.GetUserId();

        // 查找是否已有相同 token 的记录（同一设备可能换了用户）
        var existingToken = await _context.DeviceTokens
            .FirstOrDefaultAsync(dt => dt.Token == request.Token);

        if (existingToken != null)
        {
            // 更新关联用户和活跃时间
            existingToken.UserId = userId;
            existingToken.Platform = request.Platform;
            existingToken.LastActiveAt = DateTime.UtcNow;
        }
        else
        {
            // 新设备，创建 token 记录
            _context.DeviceTokens.Add(new DeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = request.Token,
                Platform = request.Platform,
                CreatedAt = DateTime.UtcNow,
                LastActiveAt = DateTime.UtcNow,
            });
        }

        await _context.SaveChangesAsync();

        _logger.LogInformation("FCM token 已注册: 用户={UserId}, 平台={Platform}", userId, request.Platform);
        return ApiResponse<object>.Ok(null, "设备令牌注册成功");
    }

    /// <summary>
    /// 清除当前用户的所有设备令牌（登出时调用）
    /// </summary>
    [HttpDelete("token")]
    public async Task<ApiResponse<object>> DeleteToken()
    {
        var userId = this.GetUserId();

        var deleted = await _context.DeviceTokens
            .Where(dt => dt.UserId == userId)
            .ExecuteDeleteAsync();

        _logger.LogInformation("FCM token 已清除: 用户={UserId}, 数量={Count}", userId, deleted);
        return ApiResponse<object>.Ok(null, "设备令牌已清除");
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
    [Required(ErrorMessage = "设备令牌不能为空")]
    [MaxLength(512, ErrorMessage = "设备令牌长度不能超过512")]
    public string Token { get; set; } = string.Empty;

    /// <summary>
    /// 平台标识（"android" / "ios"）
    /// </summary>
    [MaxLength(20)]
    public string Platform { get; set; } = "android";
}
