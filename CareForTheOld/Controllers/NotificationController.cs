using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationController : ControllerBase
{
    private readonly AppDbContext _context;

    public NotificationController(AppDbContext context) => _context = context;

    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// 获取我的通知列表
    /// </summary>
    [HttpGet("me")]
    public async Task<ApiResponse<List<NotificationRecord>>> GetMyNotifications([FromQuery] int limit = 50)
    {
        var notifications = await _context.NotificationRecords
            .Where(n => n.UserId == CurrentUserId)
            .OrderByDescending(n => n.CreatedAt)
            .Take(limit)
            .ToListAsync();

        return ApiResponse<List<NotificationRecord>>.Ok(notifications);
    }

    /// <summary>
    /// 获取未读通知数量
    /// </summary>
    [HttpGet("me/unread-count")]
    public async Task<ApiResponse<object>> GetUnreadCount()
    {
        var count = await _context.NotificationRecords
            .CountAsync(n => n.UserId == CurrentUserId && !n.IsRead);

        return ApiResponse<object>.Ok(new { count });
    }

    /// <summary>
    /// 标记单条通知已读
    /// </summary>
    [HttpPut("{id:guid}/read")]
    public async Task<ApiResponse<object>> MarkAsRead(Guid id)
    {
        var notification = await _context.NotificationRecords
            .FirstOrDefaultAsync(n => n.Id == id && n.UserId == CurrentUserId);

        if (notification == null)
            return ApiResponse<object>.Ok(new { success = false }, "通知不存在");

        notification.IsRead = true;
        await _context.SaveChangesAsync();

        return ApiResponse<object>.Ok(new { success = true }, "已标记为已读");
    }

    /// <summary>
    /// 全部标记已读
    /// </summary>
    [HttpPut("me/read-all")]
    public async Task<ApiResponse<object>> MarkAllAsRead()
    {
        var unreadNotifications = await _context.NotificationRecords
            .Where(n => n.UserId == CurrentUserId && !n.IsRead)
            .ToListAsync();

        foreach (var notification in unreadNotifications)
        {
            notification.IsRead = true;
        }

        await _context.SaveChangesAsync();

        return ApiResponse<object>.Ok(new { success = true }, "全部标记为已读");
    }
}
