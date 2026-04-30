using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// NeighborHelpService 单元测试
/// </summary>
public class NeighborHelpServiceTests
{
    private readonly AppDbContext _context;
    private readonly NeighborHelpService _service;
    private readonly Mock<INotificationService> _mockNotification;

    public NeighborHelpServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _mockNotification = new Mock<INotificationService>();
        _mockNotification.Setup(n => n.SendToUserAsync(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<object>()))
            .Returns(Task.CompletedTask);
        _mockNotification.Setup(n => n.SendToUsersAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<string>(), It.IsAny<object>()))
            .Returns(Task.CompletedTask);
        var mockLogger = new Mock<ILogger<NeighborHelpService>>();
        var mockTrustScore = new Mock<ITrustScoreService>();
        mockTrustScore.Setup(t => t.GetUserScoreAsync(It.IsAny<Guid>(), It.IsAny<Guid>()))
            .ReturnsAsync(0m);
        var mockFamilyService = new Mock<IFamilyService>();
        _service = new NeighborHelpService(_context, _mockNotification.Object, mockTrustScore.Object, mockFamilyService.Object, mockLogger.Object);
    }

    /// <summary>
    /// 创建测试用户
    /// </summary>
    private async Task<User> CreateUserAsync(
        string phone = "13900001111",
        string name = "测试用户",
        UserRole role = UserRole.Elder)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = phone,
            PasswordHash = "hash",
            RealName = name,
            BirthDate = new DateOnly(1950, 1, 1),
            Role = role
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    /// <summary>
    /// 创建完整的测试数据：老人、子女、家庭、邻里圈
    /// </summary>
    private async Task<(User Elder, User Child, Family Family, NeighborCircle Circle)> CreateTestDataAsync()
    {
        var elder = await CreateUserAsync("13900001001", "测试老人", UserRole.Elder);
        var child = await CreateUserAsync("13900001002", "测试子女", UserRole.Child);

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "测试家庭",
            CreatorId = child.Id,
            InviteCode = "111111",
        };
        _context.Families.Add(family);
        _context.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(), FamilyId = family.Id, UserId = elder.Id,
                Role = UserRole.Elder, Relation = "父亲",
                Status = FamilyMemberStatus.Approved,
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(), FamilyId = family.Id, UserId = child.Id,
                Role = UserRole.Child, Relation = "子女",
                Status = FamilyMemberStatus.Approved,
            }
        );

        var circle = new NeighborCircle
        {
            Id = Guid.NewGuid(),
            CircleName = "测试邻里圈",
            CreatorId = elder.Id,
            InviteCode = "222222",
            IsActive = true,
        };
        _context.NeighborCircles.Add(circle);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(),
            CircleId = circle.Id,
            UserId = elder.Id,
            Role = UserRole.Elder,
            Status = NeighborCircleStatus.Approved,
        });

        await _context.SaveChangesAsync();
        return (elder, child, family, circle);
    }

    [Fact]
    public async Task BroadcastHelpRequestAsync_老人未加入圈子应跳过广播()
    {
        // 准备：老人未加入任何邻里圈
        var elder = await CreateUserAsync("13900002001", "无圈子老人");
        var family = new Family
        {
            Id = Guid.NewGuid(), FamilyName = "测试", CreatorId = elder.Id, InviteCode = "000000",
        };
        _context.Families.Add(family);
        _context.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(), FamilyId = family.Id, UserId = elder.Id,
            Role = UserRole.Elder, Relation = "本人",
            Status = FamilyMemberStatus.Approved,
        });
        await _context.SaveChangesAsync();

        var call = new EmergencyCall
        {
            Id = Guid.NewGuid(), ElderId = elder.Id, FamilyId = family.Id,
            CalledAt = DateTime.UtcNow, Status = EmergencyStatus.Pending,
        };
        _context.EmergencyCalls.Add(call);
        await _context.SaveChangesAsync();

        // 执行：不应抛出异常
        await _service.BroadcastHelpRequestAsync(call.Id);

        // 验证：没有创建求助请求
        var requests = await _context.NeighborHelpRequests.ToListAsync();
        requests.Should().BeEmpty();
    }

    [Fact]
    public async Task BroadcastHelpRequestAsync_无位置信息应广播给全圈()
    {
        // 准备
        var (elder, child, family, circle) = await CreateTestDataAsync();
        var neighbor = await CreateUserAsync("13900002002", "邻居", UserRole.Elder);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(), CircleId = circle.Id, UserId = neighbor.Id,
            Role = UserRole.Elder, Status = NeighborCircleStatus.Approved,
        });
        await _context.SaveChangesAsync();

        var call = new EmergencyCall
        {
            Id = Guid.NewGuid(), ElderId = elder.Id, FamilyId = family.Id,
            CalledAt = DateTime.UtcNow, Status = EmergencyStatus.Pending,
            Latitude = null, Longitude = null, // 无位置
        };
        _context.EmergencyCalls.Add(call);
        await _context.SaveChangesAsync();

        // 执行
        await _service.BroadcastHelpRequestAsync(call.Id);

        // 验证：创建了求助请求，通知了邻居
        var requests = await _context.NeighborHelpRequests.ToListAsync();
        requests.Should().HaveCount(1);
        _mockNotification.Verify(n => n.SendToUsersAsync(
            It.Is<IEnumerable<Guid>>(ids => ids.Contains(neighbor.Id)),
            "NeighborHelpRequest", It.IsAny<object>()), Times.Once);
    }

    [Fact]
    public async Task AcceptHelpRequestAsync_应更新状态并通知各方()
    {
        // 准备
        var (elder, child, family, circle) = await CreateTestDataAsync();
        var neighbor = await CreateUserAsync("13900003001", "响应邻居", UserRole.Elder);
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(), CircleId = circle.Id, UserId = neighbor.Id,
            Role = UserRole.Elder, Status = NeighborCircleStatus.Approved,
        });

        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            Status = HelpRequestStatus.Pending,
            Latitude = 39.9042,
            Longitude = 116.4074,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        // 执行
        var result = await _service.AcceptHelpRequestAsync(request.Id, neighbor.Id);

        // 验证
        result.Should().NotBeNull();
        result.Status.Should().Be(HelpRequestStatus.Accepted);
        result.ResponderId.Should().Be(neighbor.Id);
        result.RespondedAt.Should().NotBeNull();

        // 通知老人
        _mockNotification.Verify(n => n.SendToUserAsync(
            elder.Id, "NeighborHelpAccepted", It.IsAny<object>()), Times.Once);
    }

    [Fact]
    public async Task AcceptHelpRequestAsync_非Pending状态应抛出异常()
    {
        // 准备
        var (elder, _, _, circle) = await CreateTestDataAsync();
        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            Status = HelpRequestStatus.Accepted, // 已被接受
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        var responder = await CreateUserAsync("13900003002", "第二个响应者");

        // 执行并验证
        var act = async () => await _service.AcceptHelpRequestAsync(request.Id, responder.Id);
        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage(ErrorMessages.NeighborHelp.InvalidStatus);
    }

    [Fact]
    public async Task AcceptHelpRequestAsync_不能接受自己的求助()
    {
        // 准备
        var (elder, _, _, circle) = await CreateTestDataAsync();
        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            Status = HelpRequestStatus.Pending,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        // 执行并验证
        var act = async () => await _service.AcceptHelpRequestAsync(request.Id, elder.Id);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage(ErrorMessages.NeighborHelp.CannotAcceptOwn);
    }

    [Fact]
    public async Task CancelHelpRequestAsync_老人本人应可取消()
    {
        // 准备
        var (elder, _, _, circle) = await CreateTestDataAsync();
        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            Status = HelpRequestStatus.Pending,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        // 执行
        await _service.CancelHelpRequestAsync(request.Id, elder.Id);

        // 验证
        var updated = await _context.NeighborHelpRequests.FindAsync(request.Id);
        updated!.Status.Should().Be(HelpRequestStatus.Cancelled);
        updated.CancelledBy.Should().Be(elder.Id);
    }

    [Fact]
    public async Task CancelHelpRequestAsync_非相关人员应抛出异常()
    {
        // 准备
        var (elder, _, _, circle) = await CreateTestDataAsync();
        var stranger = await CreateUserAsync("13900004002", "陌生人");

        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            Status = HelpRequestStatus.Pending,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        // 执行并验证
        var act = async () => await _service.CancelHelpRequestAsync(request.Id, stranger.Id);
        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage(ErrorMessages.NeighborHelp.OnlyRequesterOrChildCancel);
    }

    [Fact]
    public async Task RateHelpRequestAsync_应成功创建评价()
    {
        // 准备
        var (elder, child, family, circle) = await CreateTestDataAsync();
        var responder = await CreateUserAsync("13900005001", "响应者");

        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            ResponderId = responder.Id,
            Status = HelpRequestStatus.Accepted,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        var rateRequest = new RateHelpRequest { Rating = 5, Comment = "非常感谢" };

        // 执行
        var result = await _service.RateHelpRequestAsync(request.Id, elder.Id, rateRequest);

        // 验证
        result.Should().NotBeNull();
        result.Rating.Should().Be(5);
        result.Comment.Should().Be("非常感谢");
        result.RateeId.Should().Be(responder.Id);
    }

    [Fact]
    public async Task RateHelpRequestAsync_重复评价应抛出异常()
    {
        // 准备
        var (elder, _, _, circle) = await CreateTestDataAsync();
        var responder = await CreateUserAsync("13900005002", "响应者2");

        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            ResponderId = responder.Id,
            Status = HelpRequestStatus.Accepted,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        _context.NeighborHelpRatings.Add(new NeighborHelpRating
        {
            Id = Guid.NewGuid(),
            HelpRequestId = request.Id,
            RaterId = elder.Id,
            RateeId = responder.Id,
            Rating = 4,
        });
        await _context.SaveChangesAsync();

        var rateRequest = new RateHelpRequest { Rating = 5 };

        // 执行并验证
        var act = async () => await _service.RateHelpRequestAsync(request.Id, elder.Id, rateRequest);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage(ErrorMessages.NeighborHelp.AlreadyRated);
    }

    [Fact]
    public async Task GetPendingRequestsAsync_应返回同圈未过期请求()
    {
        // 准备
        var (elder, _, _, circle) = await CreateTestDataAsync();
        var member = await CreateUserAsync("13900006001", "圈子成员");
        _context.NeighborCircleMembers.Add(new NeighborCircleMember
        {
            Id = Guid.NewGuid(), CircleId = circle.Id, UserId = member.Id,
            Role = UserRole.Elder, Status = NeighborCircleStatus.Approved,
        });

        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            Status = HelpRequestStatus.Pending,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        // 执行：成员查看待响应列表（应包含 elder 发起的请求）
        var results = await _service.GetPendingRequestsAsync(member.Id);

        // 验证
        results.Should().HaveCount(1);
        results[0].RequesterName.Should().Be("测试老人");
    }

    [Fact]
    public async Task CleanupExpiredRequestsAsync_应将过期请求标记为Expired()
    {
        // 准备：创建已过期的请求
        var (elder, _, _, circle) = await CreateTestDataAsync();
        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            Status = HelpRequestStatus.Pending,
            ExpiresAt = DateTime.UtcNow.AddMinutes(-5), // 已过期
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        // 执行
        await _service.CleanupExpiredRequestsAsync();

        // 验证
        var updated = await _context.NeighborHelpRequests.FindAsync(request.Id);
        updated!.Status.Should().Be(HelpRequestStatus.Expired);
    }

    [Fact]
    public async Task CleanupExpiredRequestsAsync_未过期请求不应被清理()
    {
        // 准备
        var (elder, _, _, circle) = await CreateTestDataAsync();
        var request = new NeighborHelpRequest
        {
            Id = Guid.NewGuid(),
            EmergencyCallId = Guid.NewGuid(),
            CircleId = circle.Id,
            RequesterId = elder.Id,
            Status = HelpRequestStatus.Pending,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15), // 未过期
        };
        _context.NeighborHelpRequests.Add(request);
        await _context.SaveChangesAsync();

        // 执行
        await _service.CleanupExpiredRequestsAsync();

        // 验证
        var updated = await _context.NeighborHelpRequests.FindAsync(request.Id);
        updated!.Status.Should().Be(HelpRequestStatus.Pending);
    }
}
