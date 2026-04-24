using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// TrustScoreService 单元测试
/// </summary>
public class TrustScoreServiceTests
{
    private readonly AppDbContext _context;
    private readonly TrustScoreService _service;

    public TrustScoreServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _service = new TrustScoreService(
            _context,
            new Mock<ILogger<TrustScoreService>>().Object);
    }

    /// <summary>
    /// 创建测试用户
    /// </summary>
    private async Task<User> CreateUserAsync(
        string phone = "13800001111",
        string name = "测试用户",
        UserRole role = UserRole.Elder)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = phone,
            PasswordHash = "hash",
            RealName = name,
            BirthDate = new DateOnly(1955, 8, 10),
            Role = role
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    /// <summary>
    /// 创建测试邻里圈
    /// </summary>
    private async Task<NeighborCircle> CreateCircleAsync(Guid creatorId)
    {
        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "测试邻里圈",
            CreatorId = creatorId,
            InviteCode = "123456",
            InviteCodeExpiresAt = DateTime.UtcNow.AddDays(7),
            CenterLatitude = 39.9,
            CenterLongitude = 116.4,
            CreatedAt = DateTime.UtcNow,
        };
        _context.NeighborCircles.Add(circle);
        await _context.SaveChangesAsync();
        return circle;
    }

    /// <summary>
    /// 创建互助请求并模拟邻居响应
    /// </summary>
    private async Task<NeighborHelpRequest> CreateHelpRequestAsync(
        Guid requesterId, Guid circleId, Guid? responderId = null, HelpRequestStatus status = HelpRequestStatus.Accepted)
    {
        var elder = await _context.Users.FindAsync(requesterId);
        var call = new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = requesterId,
            Elder = elder!,
            FamilyId = Guid.NewGuid(),
            Status = EmergencyStatus.Pending,
            CalledAt = DateTime.UtcNow,
        };
        _context.EmergencyCalls.Add(call);

        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = call.Id,
            CircleId = circleId,
            RequesterId = requesterId,
            ResponderId = responderId,
            Status = status,
            RequestedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();
        return request;
    }

    [Fact]
    public async Task GetUserScoreAsync_无评分记录_返回零()
    {
        var user = await CreateUserAsync();
        var circle = await CreateCircleAsync(user.Id);

        var score = await _service.GetUserScoreAsync(user.Id, circle.Id);

        score.Should().Be(0m);
    }

    [Fact]
    public async Task OnHelpCompletedAsync_无历史记录_创建新评分()
    {
        var elder = await CreateUserAsync();
        var neighbor = await CreateUserAsync("13800002222", "邻居", UserRole.Child);
        var circle = await CreateCircleAsync(elder.Id);
        var helpRequest = await CreateHelpRequestAsync(elder.Id, circle.Id, neighbor.Id);

        await _service.OnHelpCompletedAsync(helpRequest.Id, neighbor.Id);

        var trustScore = await _context.TrustScores
            .FirstOrDefaultAsync(t => t.UserId == neighbor.Id && t.CircleId == circle.Id);

        trustScore.Should().NotBeNull();
        trustScore!.TotalHelps.Should().Be(1);
    }

    [Fact]
    public async Task OnHelpCompletedAsync_多次互助_累加互助次数()
    {
        var elder = await CreateUserAsync();
        var neighbor = await CreateUserAsync("13800002222", "邻居", UserRole.Child);
        var circle = await CreateCircleAsync(elder.Id);

        // 第一次互助
        var help1 = await CreateHelpRequestAsync(elder.Id, circle.Id, neighbor.Id);
        await _service.OnHelpCompletedAsync(help1.Id, neighbor.Id);

        // 第二次互助
        var help2 = await CreateHelpRequestAsync(elder.Id, circle.Id, neighbor.Id);
        await _service.OnHelpCompletedAsync(help2.Id, neighbor.Id);

        var trustScore = await _context.TrustScores
            .FirstOrDefaultAsync(t => t.UserId == neighbor.Id && t.CircleId == circle.Id);

        trustScore!.TotalHelps.Should().Be(2);
    }

    [Fact]
    public async Task RecalculateAllScoresAsync_含评分数据_正确计算()
    {
        var elder = await CreateUserAsync();
        var neighbor = await CreateUserAsync("13800002222", "邻居", UserRole.Child);
        var circle = await CreateCircleAsync(elder.Id);

        // 创建互助请求（已完成）
        await CreateHelpRequestAsync(elder.Id, circle.Id, neighbor.Id, HelpRequestStatus.Accepted);

        // 创建评分记录
        var helpRequest = await _context.NeighborHelpRequests.FirstAsync(r => r.ResponderId == neighbor.Id);
        _context.NeighborHelpRatings.Add(new NeighborHelpRating
        {
            Id = Guid.NewGuid(),
            HelpRequestId = helpRequest.Id,
            RaterId = elder.Id,
            RateeId = neighbor.Id,
            Rating = 5,
        });
        await _context.SaveChangesAsync();

        // 先创建 TrustScore 记录
        var trustScore = new TrustScore
        {
            Id = Guid.NewGuid(),
            UserId = neighbor.Id,
            CircleId = circle.Id,
        };
        _context.TrustScores.Add(trustScore);
        await _context.SaveChangesAsync();

        // 重算
        await _service.RecalculateAllScoresAsync();

        var updated = await _context.TrustScores
            .FirstOrDefaultAsync(t => t.UserId == neighbor.Id && t.CircleId == circle.Id);

        updated.Should().NotBeNull();
        updated!.TotalHelps.Should().Be(1);
        updated.AvgRating.Should().Be(5m);
        // 评分 5 × 8 × 0.4 = 16，互助 1/20 × 100 × 0.3 = 1.5，响应率 0 × 100 × 0.3 = 0
        updated.Score.Should().Be(17.5m);
    }

    [Fact]
    public async Task GetCircleRankingAsync_按评分降序排列()
    {
        var elder = await CreateUserAsync();
        var neighbor1 = await CreateUserAsync("13800002222", "邻居A", UserRole.Child);
        var neighbor2 = await CreateUserAsync("13800003333", "邻居B", UserRole.Child);
        var circle = await CreateCircleAsync(elder.Id);

        // 邻居A 高分
        _context.TrustScores.Add(new TrustScore
        {
            Id = Guid.NewGuid(),
            UserId = neighbor1.Id,
            CircleId = circle.Id,
            TotalHelps = 10,
            AvgRating = 4.5m,
            Score = 50m,
            LastCalculatedAt = DateTime.UtcNow,
        });

        // 邻居B 低分
        _context.TrustScores.Add(new TrustScore
        {
            Id = Guid.NewGuid(),
            UserId = neighbor2.Id,
            CircleId = circle.Id,
            TotalHelps = 2,
            AvgRating = 3m,
            Score = 20m,
            LastCalculatedAt = DateTime.UtcNow,
        });

        await _context.SaveChangesAsync();

        var ranking = await _service.GetCircleRankingAsync(circle.Id);

        ranking.Should().HaveCount(2);
        ranking[0].Score.Should().Be(50m);
        ranking[1].Score.Should().Be(20m);
    }

    [Fact]
    public async Task 评分算法_零数据_评分为零()
    {
        var user = await CreateUserAsync();
        var circle = await CreateCircleAsync(user.Id);

        var trustScore = new TrustScore
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            CircleId = circle.Id,
        };
        _context.TrustScores.Add(trustScore);
        await _context.SaveChangesAsync();

        await _service.RecalculateAllScoresAsync();

        var updated = await _context.TrustScores.FirstAsync(t => t.UserId == user.Id);
        updated.Score.Should().Be(0m);
    }
}
