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
    private readonly IFileStorageService _fileStorageService;
    /// <summary>
    /// 允许的头像文件扩展名
    /// </summary>
    private static readonly HashSet<string> _allowedExtensions = new(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png" };
    /// <summary>
    /// 允许的 MIME 内容类型
    /// </summary>
    private static readonly HashSet<string> _allowedContentTypes = new(StringComparer.OrdinalIgnoreCase) { "image/jpeg", "image/png" };
    /// <summary>
    /// 最大文件大小（2 MB）
    /// </summary>
    private const long _maxFileSize = 2 * 1024 * 1024;

    public UserController(IUserService userService, IFileStorageService fileStorageService)
    {
        _userService = userService;
        _fileStorageService = fileStorageService;
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
    /// 接受 jpg/png 格式图片，最大 2MB。通过 IFileStorageService 抽象层存储文件，
    /// 便于后续切换至云存储（OSS/S3）而无需修改 Controller 逻辑。
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

        // 文件类型验证（扩展名 + MIME 类型双重校验）
        var extension = Path.GetExtension(file.FileName);
        if (!_allowedExtensions.Contains(extension))
        {
            return ApiResponse<object>.Fail("仅支持 JPG 和 PNG 格式的图片");
        }
        if (!_allowedContentTypes.Contains(file.ContentType))
        {
            return ApiResponse<object>.Fail("文件内容类型不支持");
        }

        var userId = this.GetUserId();

        // 使用用户 ID 作为文件名，避免重复文件堆积
        var fileName = $"{userId}{extension}";

        // 通过文件存储抽象层上传，解耦文件 IO 与 Web 进程
        using var stream = file.OpenReadStream();
        var avatarUrl = await _fileStorageService.UploadAsync("avatars", fileName, stream, file.ContentType);

        // 更新用户头像 URL
        await _userService.UpdateAvatarUrlAsync(userId, avatarUrl);

        return ApiResponse<object>.Ok(new { avatarUrl }, "头像上传成功");
    }

    [HttpGet("{id:guid}")]
    public async Task<ApiResponse<UserResponse>> GetUserById(Guid id)
    {
        // 仅允许查看本人或同一家庭成员的信息，防止越权访问
        var currentUserId = this.GetUserId();
        if (id != currentUserId)
        {
            // 非本人查询：由服务层校验家庭成员关系
            await _userService.EnsureFamilyMemberAsync(currentUserId, id);
        }
        var result = await _userService.GetUserByIdAsync(id);
        return ApiResponse<UserResponse>.Ok(result);
    }
}
