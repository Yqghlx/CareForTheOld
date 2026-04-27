using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using static CareForTheOld.Common.Extensions.ControllerExtensions;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Controllers;

/// <summary>
/// 通知控制器
/// 提供通知列表查询、标记已读、批量操作等功能
/// 支持 SignalR 实时推送和离线通知同步
/// </summary>
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
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheShortSeconds)]
    public async Task<ApiResponse<List<NotificationResponse>>> GetMyNotifications([FromQuery][Range(1, int.MaxValue)] int limit = AppConstants.Pagination.DefaultPageSize)
    {
        var notifications = await _notificationService.GetUserNotificationsAsync(this.GetUserId(), limit);
        return ApiResponse<List<NotificationResponse>>.Ok(notifications);
    }

    /// <summary>
    /// 获取未读通知数量
    /// </summary>
    [HttpGet("me/unread-count")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheShortSeconds)]
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
            return ApiResponse<object>.Ok(new { success = false }, SuccessMessages.Notification.NotFound);

        return ApiResponse<object>.Ok(new { success = true }, SuccessMessages.Notification.MarkedRead);
    }

    /// <summary>
    /// 全部标记已读
    /// </summary>
    [HttpPut("me/read-all")]
    public async Task<ApiResponse<object>> MarkAllAsRead()
    {
        await _notificationService.MarkAllAsReadAsync(this.GetUserId());
        return ApiResponse<object>.Ok(new { success = true }, SuccessMessages.Notification.AllMarkedRead);
    }
}
