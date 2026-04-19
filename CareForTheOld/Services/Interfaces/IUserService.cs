using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

public interface IUserService
{
    Task<UserResponse> GetCurrentUserAsync(Guid userId);
    Task<UserResponse> GetUserByIdAsync(Guid userId);
    Task<UserResponse> UpdateUserAsync(Guid userId, UpdateUserRequest request);
    Task<bool> ChangePasswordAsync(Guid userId, ChangePasswordRequest request);

    /// <summary>
    /// 更新用户头像 URL
    /// </summary>
    Task UpdateAvatarUrlAsync(Guid userId, string avatarUrl);

    /// <summary>
    /// 验证两个用户是否在同一家庭中，否则抛出 UnauthorizedAccessException
    /// </summary>
    Task EnsureFamilyMemberAsync(Guid currentUserId, Guid targetUserId);
}