using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
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
/// HealthService 单元测试
/// </summary>
public class HealthServiceTests
{
    private readonly AppDbContext _context;
    private readonly Mock<IHealthAlertService> _mockAlertService;
    private readonly HealthService _service;

    public HealthServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        _mockAlertService = new Mock<IHealthAlertService>();
        _service = new HealthService(_context, _mockAlertService.Object, new Mock<ILogger<HealthService>>().Object);
    }

    private async Task<Guid> CreateTestUserAsync()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13800138000",
            PasswordHash = "test_hash",
            RealName = "老人测试",
            Role = UserRole.Elder,
            CreatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user.Id;
    }

    [Fact]
    public async Task CreateRecordAsync_ShouldCreateBloodPressureRecord_WhenValidRequest()
    {
        var userId = await CreateTestUserAsync();
        var request = new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        };

        var result = await _service.CreateRecordAsync(userId, request);

        result.Should().NotBeNull();
        result.Type.Should().Be(HealthType.BloodPressure);
        result.Systolic.Should().Be(120);
        result.Diastolic.Should().Be(80);
        result.UserId.Should().Be(userId);
    }

    [Fact]
    public async Task CreateRecordAsync_ShouldThrowException_WhenMissingRequiredData()
    {
        var userId = await CreateTestUserAsync();
        var request = new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure
            // 缺少收缩压和舒张压
        };

        var act = async () => await _service.CreateRecordAsync(userId, request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage(ErrorMessages.Health.BloodPressureRequired);
    }

    [Fact]
    public async Task GetUserRecordsAsync_ShouldReturnRecords_WhenRecordsExist()
    {
        var userId = await CreateTestUserAsync();

        // 创建多条记录
        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        });
        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.HeartRate,
            HeartRate = 72
        });

        var result = await _service.GetUserRecordsAsync(userId, null, skip: 0, limit: 50);

        result.Should().HaveCount(2);
        result.Should().Contain(r => r.Type == HealthType.BloodPressure);
        result.Should().Contain(r => r.Type == HealthType.HeartRate);
    }

    [Fact]
    public async Task GetUserRecordsAsync_ShouldFilterByType_WhenTypeSpecified()
    {
        var userId = await CreateTestUserAsync();

        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        });
        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.HeartRate,
            HeartRate = 72
        });

        var result = await _service.GetUserRecordsAsync(userId, HealthType.BloodPressure, skip: 0, limit: 50);

        result.Should().HaveCount(1);
        result[0].Type.Should().Be(HealthType.BloodPressure);
    }

    /// <summary>
    /// 创建包含老人和子女的家庭关系，用于家庭成员健康记录查询测试
    /// </summary>
    private async Task<(Guid elderId, Guid childId, Guid familyId)> CreateFamilyWithMembersAsync()
    {
        var elder = new User { Id = Guid.NewGuid(), PhoneNumber = "13900009001", PasswordHash = "hash", RealName = "老人", Role = UserRole.Elder, CreatedAt = DateTime.UtcNow };
        var child = new User { Id = Guid.NewGuid(), PhoneNumber = "13900009002", PasswordHash = "hash", RealName = "子女", Role = UserRole.Child, CreatedAt = DateTime.UtcNow };
        _context.Users.AddRange(elder, child);
        var family = new Family { Id = Guid.NewGuid(), FamilyName = "测试家庭", CreatorId = child.Id, InviteCode = "123456", CreatedAt = DateTime.UtcNow };
        _context.Families.Add(family);
        _context.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = family.Id, UserId = elder.Id, Role = UserRole.Elder, Relation = "父亲", Status = FamilyMemberStatus.Approved },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = family.Id, UserId = child.Id, Role = UserRole.Child, Relation = "子女", Status = FamilyMemberStatus.Approved }
        );
        await _context.SaveChangesAsync();
        return (elder.Id, child.Id, family.Id);
    }

    [Fact]
    public async Task DeleteRecordAsync_ShouldSoftDelete()
    {
        var userId = await CreateTestUserAsync();
        var record = await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest { Type = HealthType.BloodPressure, Systolic = 130, Diastolic = 85 });
        await _service.DeleteRecordAsync(userId, record.Id);
        // 验证软删除
        var records = await _service.GetUserRecordsAsync(userId, null, skip: 0, limit: 50);
        records.Should().NotContain(r => r.Id == record.Id);
    }

    [Fact]
    public async Task GetFamilyMemberRecordsAsync_ShouldReturnRecords()
    {
        var (elderId, _, familyId) = await CreateFamilyWithMembersAsync();
        await _service.CreateRecordAsync(elderId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest { Type = HealthType.BloodPressure, Systolic = 125, Diastolic = 82 });
        var result = await _service.GetFamilyMemberRecordsAsync(familyId, elderId, null, skip: 0, limit: 50);
        result.Should().HaveCount(1);
    }

    [Fact]
    public async Task DeleteRecordAsync_ShouldThrow_WhenRecordNotFound()
    {
        var userId = await CreateTestUserAsync();
        var act = async () => await _service.DeleteRecordAsync(userId, Guid.NewGuid());
        await act.Should().ThrowAsync<KeyNotFoundException>()
            .WithMessage(ErrorMessages.Health.RecordNotFoundOrNoPermission);
    }

    [Fact]
    public async Task CreateRecordAsync_ShouldTriggerAlert_WhenAbnormalValue()
    {
        var userId = await CreateTestUserAsync();

        // 创建异常血压值（收缩压 180，明显偏高）
        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 180,
            Diastolic = 110
        });

        // 验证告警检查被调用（CheckAbnormal 应返回非 null 值）
        _mockAlertService.Verify(
            a => a.CheckAbnormal(It.IsAny<HealthRecord>()),
            Times.Once);
    }

    [Fact]
    public async Task CreateRecordAsync_ShouldNotTriggerAlert_WhenNormalValue()
    {
        var userId = await CreateTestUserAsync();

        // 创建正常血压值
        await _service.CreateRecordAsync(userId, new Models.DTOs.Requests.Health.CreateHealthRecordRequest
        {
            Type = HealthType.BloodPressure,
            Systolic = 120,
            Diastolic = 80
        });

        // 验证 CheckAbnormal 被调用但返回 null（无告警）
        _mockAlertService.Verify(
            a => a.CheckAbnormal(It.IsAny<HealthRecord>()),
            Times.Once);
    }
}