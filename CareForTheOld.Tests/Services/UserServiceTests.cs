using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// UserService 单元测试
/// </summary>
public class UserServiceTests
{
    private readonly AppDbContext _context;
    private readonly UserService _service;

    public UserServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _service = new UserService(_context);
    }

    private async Task<Guid> CreateTestUserAsync()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800138000",
            PasswordHash = "test_hash",
            RealName = "测试用户",
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user.Id;
    }

    [Fact]
    public async Task GetCurrentUserAsync_ShouldReturnUser_WhenUserExists()
    {
        var userId = await CreateTestUserAsync();

        var result = await _service.GetCurrentUserAsync(userId);

        result.Should().NotBeNull();
        result.Id.Should().Be(userId);
        result.PhoneNumber.Should().Be("13800138000");
        result.RealName.Should().Be("测试用户");
    }

    [Fact]
    public async Task GetCurrentUserAsync_ShouldThrowException_WhenUserNotFound()
    {
        var nonExistentId = Guid.NewGuid();

        var act = async () => await _service.GetCurrentUserAsync(nonExistentId);
        await act.Should().ThrowAsync<KeyNotFoundException>();
    }

    [Fact]
    public async Task UpdateUserAsync_ShouldUpdateRealName_WhenValidRequest()
    {
        var userId = await CreateTestUserAsync();
        var request = new UpdateUserRequest { RealName = "新名字" };

        var result = await _service.UpdateUserAsync(userId, request);

        result.RealName.Should().Be("新名字");
    }

    [Fact]
    public async Task UpdateUserAsync_ShouldUpdateAvatarUrl_WhenValidRequest()
    {
        var userId = await CreateTestUserAsync();
        var request = new UpdateUserRequest { AvatarUrl = "https://example.com/avatar.jpg" };

        var result = await _service.UpdateUserAsync(userId, request);

        result.AvatarUrl.Should().Be("https://example.com/avatar.jpg");
    }
}