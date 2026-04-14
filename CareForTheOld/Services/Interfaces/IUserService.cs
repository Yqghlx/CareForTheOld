using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

public interface IUserService
{
    Task<UserResponse> GetCurrentUserAsync(Guid userId);
    Task<UserResponse> GetUserByIdAsync(Guid userId);
    Task<UserResponse> UpdateUserAsync(Guid userId, UpdateUserRequest request);
    Task<bool> ChangePasswordAsync(Guid userId, ChangePasswordRequest request);
}