using Asp.Versioning;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using static CareForTheOld.Common.Extensions.ControllerExtensions;

namespace CareForTheOld.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class NotificationController : ControllerBase
{
    private readonly INotificationService _notificationService;

    public NotificationController(INotificationService notificationService)
    {
        _notificationService = notificationService;
    }

    /// <summary>
    /// 获取我的通知列表
    /// </summary>
    [HttpGet("me")]
    public async Task<ApiResponse<List<NotificationResponse>>> GetMyNotifications([FromQuery] int limit = 50)
    {
        var notifications = await _notificationService.GetUserNotificationsAsync(this.GetUserId(), limit);
        return ApiResponse<List<NotificationResponse>>.Ok(notifications);
    }

    /// <summary>
    /// 获取未读通知数量
    /// </summary>
    [HttpGet("me/unread-count")]
    public async Task<ApiResponse<object>> GetUnreadCount()
    {
        var count = await _notificationService.GetUnreadCountAsync(this.GetUserId());
        return ApiResponse<object>.Ok(new { count });
    }

    /// <summary>
    /// 标记单条通知已读
    /// </summary>
    [HttpPut("{id:guid}/read")]
    public async Task<ApiResponse<object>> MarkAsRead(Guid id)
    {
        var success = await _notificationService.MarkAsReadAsync(id, this.GetUserId());

        if (!success)
            return ApiResponse<object>.Ok(new { success = false }, "通知不存在");

        return ApiResponse<object>.Ok(new { success = true }, "已标记为已读");
    }

    /// <summary>
    /// 全部标记已读
    /// </summary>
    [HttpPut("me/read-all")]
    public async Task<ApiResponse<object>> MarkAllAsRead()
    {
        await _notificationService.MarkAllAsReadAsync(this.GetUserId());
        return ApiResponse<object>.Ok(new { success = true }, "全部标记为已读");
    }
}
