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
        return await MapToResponse(userId)!;
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