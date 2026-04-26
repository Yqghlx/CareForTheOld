using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

/// <summary>
/// 用户管理控制器
/// 提供用户信息查询、更新和头像上传等功能
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class UserController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly IFileStorageService _fileStorageService;

    public UserController(IUserService userService, IFileStorageService fileStorageService)
    {
        _userService = userService;
        _fileStorageService = fileStorageService;
    }

    /// <summary>
    /// 获取当前登录用户信息
    /// </summary>
    [HttpGet("me")]
    [CacheControl(MaxAgeSeconds = 60)]
    public async Task<ApiResponse<UserResponse>> GetCurrentUser()
    {
        var userId = this.GetUserId();
        var result = await _userService.GetCurrentUserAsync(userId);
        return ApiResponse<UserResponse>.Ok(result);
    }

    /// <summary>
    /// 更新当前用户信息（昵称、头像URL）
    /// </summary>
    [HttpPut("me")]
    public async Task<ApiResponse<UserResponse>> UpdateUser([FromBody] UpdateUserRequest request)
    {
        var userId = this.GetUserId();
        var result = await _userService.UpdateUserAsync(userId, request);
        return ApiResponse<UserResponse>.Ok(result, SuccessMessages.User.UpdateSuccess);
    }

    /// <summary>
    /// 修改当前用户密码
    /// </summary>
    [HttpPost("me/password")]
    public async Task<ApiResponse<object>> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var userId = this.GetUserId();
        await _userService.ChangePasswordAsync(userId, request);
        return ApiResponse<object>.Ok(null!, SuccessMessages.User.PasswordChanged);
    }

    /// <summary>
    /// 上传用户头像
    /// </summary>
    /// <remarks>
    /// 接受 jpg/png 格式图片，最大 2MB。通过 IFileStorageService 抽象层存储文件，
    /// 便于后续切换至云存储（OSS/S3）而无需修改 Controller 逻辑。
    /// </remarks>
    [HttpPost("me/avatar")]
    [RequestSizeLimit(AppConstants.FileUpload.MaxAvatarSizeBytes)]
    public async Task<ApiResponse<object>> UploadAvatar(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            return ApiResponse<object>.Fail(ErrorMessages.FileUpload.NoFileSelected);
        }

        // 文件大小验证
        if (file.Length > AppConstants.FileUpload.MaxAvatarSizeBytes)
        {
            return ApiResponse<object>.Fail(ErrorMessages.FileUpload.FileTooLarge);
        }

        // 文件类型验证（扩展名 + MIME 类型双重校验）
        var extension = Path.GetExtension(file.FileName);
        if (!AppConstants.FileUpload.AllowedAvatarExtensions.Contains(extension))
        {
            return ApiResponse<object>.Fail(ErrorMessages.FileUpload.InvalidFormat);
        }
        if (!AppConstants.FileUpload.AllowedAvatarContentTypes.Contains(file.ContentType))
        {
            return ApiResponse<object>.Fail(ErrorMessages.FileUpload.InvalidContentType);
        }

        var userId = this.GetUserId();

        // 使用用户 ID 作为文件名，避免重复文件堆积
        var fileName = $"{userId}{extension}";

        // 通过文件存储抽象层上传，解耦文件 IO 与 Web 进程
        using var stream = file.OpenReadStream();
        var avatarUrl = await _fileStorageService.UploadAsync("avatars", fileName, stream, file.ContentType);

        // 更新用户头像 URL
        await _userService.UpdateAvatarUrlAsync(userId, avatarUrl);

        return ApiResponse<object>.Ok(new { avatarUrl }, SuccessMessages.User.AvatarUploaded);
    }

    [HttpGet("{id:guid}")]
    [CacheControl(MaxAgeSeconds = 60)]
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
