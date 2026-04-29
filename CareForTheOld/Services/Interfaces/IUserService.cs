using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

public interface IUserService
{
    /// <summary>获取当前用户信息</summary>
    Task<UserResponse> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>根据 ID 获取用户信息</summary>
    Task<UserResponse> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>更新用户信息（昵称、头像URL）</summary>
    Task<UserResponse> UpdateUserAsync(Guid userId, UpdateUserRequest request, CancellationToken cancellationToken = default);

    /// <summary>修改用户密码（需验证旧密码）</summary>
    Task<bool> ChangePasswordAsync(Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken = default);

    /// <summary>
    /// 更新用户头像 URL
    /// </summary>
    Task UpdateAvatarUrlAsync(Guid userId, string avatarUrl, CancellationToken cancellationToken = default);

    /// <summary>
    /// 验证两个用户是否在同一家庭中，否则抛出 UnauthorizedAccessException
    /// </summary>
    Task EnsureFamilyMemberAsync(Guid currentUserId, Guid targetUserId, CancellationToken cancellationToken = default);
}