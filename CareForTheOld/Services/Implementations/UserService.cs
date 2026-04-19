using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

public class UserService : IUserService
{
    private readonly AppDbContext _context;

    public UserService(AppDbContext context) => _context = context;

    public async Task<UserResponse> GetCurrentUserAsync(Guid userId)
        => await MapToResponse(userId) ?? throw new KeyNotFoundException("用户不存在");

    public async Task<UserResponse> GetUserByIdAsync(Guid userId)
        => await MapToResponse(userId) ?? throw new KeyNotFoundException("用户不存在");

    public async Task<UserResponse> UpdateUserAsync(Guid userId, UpdateUserRequest request)
    {
        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("用户不存在");

        if (request.RealName is not null) user.RealName = request.RealName;
        if (request.AvatarUrl is not null) user.AvatarUrl = request.AvatarUrl;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return await MapToResponse(userId) ?? throw new KeyNotFoundException("用户不存在");
    }

    public async Task<bool> ChangePasswordAsync(Guid userId, ChangePasswordRequest request)
    {
        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("用户不存在");

        // 验证旧密码
        if (!BCrypt.Net.BCrypt.Verify(request.OldPassword, user.PasswordHash))
        {
            throw new InvalidOperationException("旧密码不正确");
        }

        // 更新新密码
        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    /// <summary>
    /// 更新用户头像 URL
    /// </summary>
    public async Task UpdateAvatarUrlAsync(Guid userId, string avatarUrl)
    {
        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("用户不存在");

        user.AvatarUrl = avatarUrl;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }

    /// <summary>
    /// 验证两个用户是否在同一家庭中，否则抛出 UnauthorizedAccessException
    /// </summary>
    public async Task EnsureFamilyMemberAsync(Guid currentUserId, Guid targetUserId)
    {
        var currentFamilyId = await _context.FamilyMembers
            .Where(fm => fm.UserId == currentUserId)
            .Select(fm => fm.FamilyId)
            .FirstOrDefaultAsync();

        if (currentFamilyId == Guid.Empty)
            throw new UnauthorizedAccessException("您不是该用户的家庭成员，无权查看");

        var isInSameFamily = await _context.FamilyMembers
            .AnyAsync(fm => fm.UserId == targetUserId && fm.FamilyId == currentFamilyId);

        if (!isInSameFamily)
            throw new UnauthorizedAccessException("您不是该用户的家庭成员，无权查看");
    }

    private async Task<UserResponse?> MapToResponse(Guid userId)
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
            .FirstOrDefaultAsync();
    }
}