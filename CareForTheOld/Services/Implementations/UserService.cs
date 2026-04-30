using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 用户管理服务
/// 提供用户信息查询、更新、密码修改、头像管理、权限验证等功能
/// </summary>
public class UserService : IUserService
{
    private readonly AppDbContext _context;
    private readonly ILogger<UserService> _logger;
    private readonly IAuthService _authService;

    public UserService(AppDbContext context, ILogger<UserService> logger, IAuthService authService)
    {
        _context = context;
        _logger = logger;
        _authService = authService;
    }

    /// <summary>
    /// 获取当前用户信息
    /// </summary>
    public async Task<UserResponse> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken = default)
        => await MapToResponse(userId, cancellationToken) ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

    /// <summary>
    /// 根据用户 ID 获取用户信息（非本人手机号脱敏）
    /// </summary>
    public async Task<UserResponse> GetUserByIdAsync(Guid userId, Guid requesterId, CancellationToken cancellationToken = default)
    {
        var response = await MapToResponse(userId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 非本人查看时脱敏手机号
        if (userId != requesterId)
        {
            response.PhoneNumber = response.PhoneNumber.MaskPhoneNumber();
        }

        return response;
    }

    /// <summary>
    /// 更新用户信息：支持修改昵称和头像 URL
    /// </summary>
    public async Task<UserResponse> UpdateUserAsync(Guid userId, UpdateUserRequest request, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users.AsTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        if (request.RealName is not null) user.RealName = request.RealName;
        if (request.AvatarUrl is not null) user.AvatarUrl = request.AvatarUrl;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("用户 {UserId} 更新个人信息成功", userId);

        return new UserResponse
        {
            Id = user.Id,
            PhoneNumber = user.PhoneNumber,
            RealName = user.RealName,
            BirthDate = user.BirthDate,
            Role = user.Role,
            AvatarUrl = user.AvatarUrl,
        };
    }

    /// <summary>
    /// 修改用户密码：需验证旧密码，验证通过后使用 BCrypt 哈希新密码并更新
    /// </summary>
    public async Task<bool> ChangePasswordAsync(Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users.AsTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 验证旧密码
        if (!BCrypt.Net.BCrypt.Verify(request.OldPassword, user.PasswordHash))
        {
            throw new InvalidOperationException(ErrorMessages.User.OldPasswordIncorrect);
        }

        // 更新新密码
        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;

        // 清除所有设备的 FCM token，强制重新登录
        var removedTokenCount = await _context.DeviceTokens
            .Where(dt => dt.UserId == userId)
            .ExecuteDeleteAsync(cancellationToken);

        await _context.SaveChangesAsync(cancellationToken);

        // 密码修改后吊销所有刷新令牌，强制重新登录
        await _authService.RevokeAllUserTokensAsync(userId, cancellationToken);

        _logger.LogInformation("用户 {UserId} 修改密码成功，已清除 {Count} 个设备令牌并吊销所有刷新令牌", userId, removedTokenCount);
        return true;
    }

    /// <summary>
    /// 更新用户头像 URL
    /// </summary>
    public async Task UpdateAvatarUrlAsync(Guid userId, string avatarUrl, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users.AsTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        user.AvatarUrl = avatarUrl;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("用户 {UserId} 更新头像成功", userId);
    }

    /// <summary>
    /// 验证两个用户是否在同一家庭中，否则抛出 UnauthorizedAccessException
    /// </summary>
    public async Task EnsureFamilyMemberAsync(Guid currentUserId, Guid targetUserId, CancellationToken cancellationToken = default)
    {
        var currentFamilyId = await _context.FamilyMembers
            .Where(fm => fm.UserId == currentUserId)
            .Select(fm => fm.FamilyId)
            .FirstOrDefaultAsync(cancellationToken);

        if (currentFamilyId == Guid.Empty)
            throw new UnauthorizedAccessException(ErrorMessages.User.NoPermissionToView);

        var isInSameFamily = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == targetUserId && fm.FamilyId == currentFamilyId, cancellationToken);

        if (!isInSameFamily)
            throw new UnauthorizedAccessException(ErrorMessages.User.NoPermissionToView);
    }

    private async Task<UserResponse?> MapToResponse(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.Users
            .Where(u => u.Id == userId)
            .Select(u => new UserResponse
            {
                Id = u.Id,
                PhoneNumber = u.PhoneNumber,
                RealName = u.RealName,
                BirthDate = u.BirthDate,
                Role = u.Role,
                AvatarUrl = u.AvatarUrl,
            })
            .FirstOrDefaultAsync(cancellationToken);
    }
}