using Asp.Versioning;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class UserController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly IWebHostEnvironment _env;
    /// <summary>
    /// 允许的头像文件扩展名
    /// </summary>
    private static readonly HashSet<string> _allowedExtensions = new(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png" };
    /// <summary>
    /// 最大文件大小（2 MB）
    /// </summary>
    private const long _maxFileSize = 2 * 1024 * 1024;

    public UserController(IUserService userService, IWebHostEnvironment env)
    {
        _userService = userService;
        _env = env;
    }

    [HttpGet("me")]
    public async Task<ApiResponse<UserResponse>> GetCurrentUser()
    {
        var userId = this.GetUserId();
        var result = await _userService.GetCurrentUserAsync(userId);
        return ApiResponse<UserResponse>.Ok(result);
    }

    [HttpPut("me")]
    public async Task<ApiResponse<UserResponse>> UpdateUser([FromBody] UpdateUserRequest request)
    {
        var userId = this.GetUserId();
        var result = await _userService.UpdateUserAsync(userId, request);
        return ApiResponse<UserResponse>.Ok(result, "更新成功");
    }

    [HttpPost("me/password")]
    public async Task<ApiResponse<object>> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var userId = this.GetUserId();
        await _userService.ChangePasswordAsync(userId, request);
        return ApiResponse<object>.Ok(null!, "密码修改成功");
    }

    /// <summary>
    /// 上传用户头像
    /// </summary>
    /// <remarks>
    /// 接受 jpg/png 格式图片，最大 2MB。文件保存到 uploads/avatars/ 目录，
    /// 并更新用户的 AvatarUrl 字段。
    /// </remarks>
    [HttpPost("me/avatar")]
    [RequestSizeLimit(_maxFileSize)]
    public async Task<ApiResponse<object>> UploadAvatar(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            return ApiResponse<object>.Fail("请选择要上传的头像文件");
        }

        // 文件大小验证
        if (file.Length > _maxFileSize)
        {
            return ApiResponse<object>.Fail("文件大小不能超过 2MB");
        }

        // 文件类型验证
        var extension = Path.GetExtension(file.FileName);
        if (!_allowedExtensions.Contains(extension))
        {
            return ApiResponse<object>.Fail("仅支持 JPG 和 PNG 格式的图片");
        }

        var userId = this.GetUserId();

        // 确保上传目录存在
        var uploadsDir = Path.Combine(_env.ContentRootPath, "uploads", "avatars");
        Directory.CreateDirectory(uploadsDir);

        // 使用用户 ID 作为文件名，避免重复文件堆积
        var fileName = $"{userId}{extension}";
        var filePath = Path.Combine(uploadsDir, fileName);

        // 保存文件
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        // 生成访问 URL（使用 api 前缀，便于后续配置静态文件中间件）
        var avatarUrl = $"/uploads/avatars/{fileName}";

        // 更新用户头像 URL
        await _userService.UpdateAvatarUrlAsync(userId, avatarUrl);

        return ApiResponse<object>.Ok(new { avatarUrl }, "头像上传成功");
    }

    [HttpGet("{id:guid}")]
    public async Task<ApiResponse<UserResponse>> GetUserById(Guid id)
    {
        var result = await _userService.GetUserByIdAsync(id);
        return ApiResponse<UserResponse>.Ok(result);
    }
}
