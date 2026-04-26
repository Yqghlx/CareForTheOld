using System.Security.Claims;
using CareForTheOld.Common.Constants;
using Microsoft.AspNetCore.Mvc;

namespace CareForTheOld.Common.Extensions;

/// <summary>
/// Controller 扩展方法
/// </summary>
public static class ControllerExtensions
{
    /// <summary>
    /// 安全获取当前用户 ID，解析失败返回 null
    /// </summary>
    public static Guid? TryGetUserId(this ControllerBase controller)
    {
        var userIdClaim = controller.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim))
            return null;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    /// <summary>
    /// 获取当前用户 ID，解析失败抛出 UnauthorizedAccessException
    /// </summary>
    public static Guid GetUserId(this ControllerBase controller)
    {
        return controller.TryGetUserId()
            ?? throw new UnauthorizedAccessException(ErrorMessages.Common.UserIdentityNotFound);
    }

    /// <summary>
    /// 校验并限制分页参数到合法范围
    /// </summary>
    public static int ClampLimit(this ControllerBase _, int limit)
    {
        return Math.Clamp(limit, AppConstants.Pagination.MinPageSize, AppConstants.Pagination.MaxPageSize);
    }
}
