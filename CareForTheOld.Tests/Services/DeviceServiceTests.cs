using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// DeviceService 单元测试
/// </summary>
public class DeviceServiceTests
{
    private readonly AppDbContext _context;
    private readonly DeviceService _service;

    public DeviceServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _service = new DeviceService(_context, Mock.Of<ILogger<DeviceService>>());
    }

    [Fact]
    public async Task RegisterTokenAsync_ShouldCreateNewToken_WhenNotExists()
    {
        var userId = Guid.NewGuid();

        await _service.RegisterTokenAsync(userId, "token_new", "android");

        var token = await _context.DeviceTokens.FirstOrDefaultAsync();
        token.Should().NotBeNull();
        token!.Token.Should().Be("token_new");
        token.UserId.Should().Be(userId);
        token.Platform.Should().Be("android");
    }

    [Fact]
    public async Task RegisterTokenAsync_ShouldUpdateExistingToken_WhenSameTokenExists()
    {
        var userId1 = Guid.NewGuid();
        var userId2 = Guid.NewGuid();
        var now = DateTime.UtcNow;

        _context.DeviceTokens.Add(new DeviceToken
        {
            Id = Guid.NewGuid(),
            UserId = userId1,
            Token = "existing_token",
            Platform = "android",
            CreatedAt = now,
            LastActiveAt = now,
        });
        await _context.SaveChangesAsync();

        await _service.RegisterTokenAsync(userId2, "existing_token", "ios");

        var tokens = await _context.DeviceTokens.ToListAsync();
        tokens.Should().HaveCount(1);
        tokens[0].UserId.Should().Be(userId2);
        tokens[0].Platform.Should().Be("ios");
    }

    [Fact]
    public async Task RegisterTokenAsync_ShouldHandleConcurrentConflict()
    {
        var userId = Guid.NewGuid();

        // 模拟并发冲突：先插入一个同 token 的记录
        _context.DeviceTokens.Add(new DeviceToken
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            Token = "conflict_token",
            Platform = "android",
            CreatedAt = DateTime.UtcNow,
            LastActiveAt = DateTime.UtcNow,
        });
        await _context.SaveChangesAsync();

        // 再次注册同 token 应成功更新
        await _service.RegisterTokenAsync(userId, "conflict_token", "ios");

        var tokens = await _context.DeviceTokens.Where(t => t.Token == "conflict_token").ToListAsync();
        tokens.Should().HaveCount(1);
        tokens[0].UserId.Should().Be(userId);
    }

    [Fact]
    public async Task DeleteTokensAsync_ShouldRemoveAllTokensForUser()
    {
        var userId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();

        _context.DeviceTokens.AddRange(
            new DeviceToken { Id = Guid.NewGuid(), UserId = userId, Token = "token1", Platform = "android", CreatedAt = DateTime.UtcNow, LastActiveAt = DateTime.UtcNow },
            new DeviceToken { Id = Guid.NewGuid(), UserId = userId, Token = "token2", Platform = "ios", CreatedAt = DateTime.UtcNow, LastActiveAt = DateTime.UtcNow },
            new DeviceToken { Id = Guid.NewGuid(), UserId = otherUserId, Token = "token3", Platform = "android", CreatedAt = DateTime.UtcNow, LastActiveAt = DateTime.UtcNow }
        );
        await _context.SaveChangesAsync();

        var deleted = await _service.DeleteTokensAsync(userId);

        deleted.Should().Be(2);
        var remaining = await _context.DeviceTokens.ToListAsync();
        remaining.Should().HaveCount(1);
        remaining[0].UserId.Should().Be(otherUserId);
    }

    [Fact]
    public async Task DeleteTokensAsync_ShouldReturnZero_WhenNoTokens()
    {
        var userId = Guid.NewGuid();

        var deleted = await _service.DeleteTokensAsync(userId);

        deleted.Should().Be(0);
    }
}
