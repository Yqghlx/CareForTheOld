using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Medication;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// MedicationService 单元测试
/// </summary>
public class MedicationServiceTests
{
    private readonly AppDbContext _context;
    private readonly MedicationService _service;

    public MedicationServiceTests()
    {
        // 使用 InMemory 数据库，GUID 命名确保测试隔离
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new AppDbContext(options);
        var mockNotification = new Mock<INotificationService>();
        _service = new MedicationService(_context, new FamilyService(_context, mockNotification.Object, NullLogger<FamilyService>.Instance), NullLogger<MedicationService>.Instance);
    }

    /// <summary>
    /// 创建基础测试数据：老人用户、子女用户、家庭组、家庭成员关系
    /// </summary>
    private async Task<(User elder, User child, Family family)> CreateTestDataAsync()
    {
        var elder = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13900001111",
            PasswordHash = "hash",
            RealName = "用药老人",
            BirthDate = new DateOnly(1948, 6, 20),
            Role = UserRole.Elder
        };

        var child = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13900002222",
            PasswordHash = "hash",
            RealName = "用药子女",
            BirthDate = new DateOnly(1988, 3, 5),
            Role = UserRole.Child
        };

        var family = new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = "用药测试家庭",
            CreatorId = child.Id,
            InviteCode = "654321",
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.AddRange(elder, child);
        _context.Families.Add(family);
        _context.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = elder.Id,
                Role = UserRole.Elder,
                Relation = "母亲",
                Status = FamilyMemberStatus.Approved
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                UserId = child.Id,
                Role = UserRole.Child,
                Relation = "女儿",
                Status = FamilyMemberStatus.Approved
            }
        );
        await _context.SaveChangesAsync();
        return (elder, child, family);
    }

    [Fact]
    public async Task CreatePlanAsync_ShouldCreatePlan()
    {
        // 准备：创建老人和子女的家庭关系
        var (elder, child, _) = await CreateTestDataAsync();

        var request = new CreateMedicationPlanRequest
        {
            ElderId = elder.Id,
            MedicineName = "阿司匹林",
            Dosage = "100mg",
            Frequency = Frequency.OnceDaily,
            ReminderTimes = ["08:00"],
            StartDate = DateOnly.FromDateTime(DateTime.UtcNow)
        };

        // 执行：子女为老人创建用药计划
        var result = await _service.CreatePlanAsync(child.Id, request);

        // 验证：计划创建成功
        result.Should().NotBeNull();
        result.ElderId.Should().Be(elder.Id);
        result.ElderName.Should().Be("用药老人");
        result.MedicineName.Should().Be("阿司匹林");
        result.Dosage.Should().Be("100mg");
        result.Frequency.Should().Be(Frequency.OnceDaily);
        result.ReminderTimes.Should().BeEquivalentTo(["08:00"]);
        result.IsActive.Should().BeTrue();

        // 验证：数据库中存在该记录
        var planInDb = await _context.MedicationPlans.FirstOrDefaultAsync(p => p.Id == result.Id);
        planInDb.Should().NotBeNull();
        planInDb!.IsDeleted.Should().BeFalse();
    }

    [Fact]
    public async Task CreatePlanAsync_ShouldThrow_WhenInvalidReminderTimes()
    {
        // 准备：创建家庭关系
        var (elder, child, _) = await CreateTestDataAsync();

        var request = new CreateMedicationPlanRequest
        {
            ElderId = elder.Id,
            MedicineName = "布洛芬",
            Dosage = "200mg",
            Frequency = Frequency.TwiceDaily,
            ReminderTimes = ["25:00"],  // 无效时间格式
            StartDate = DateOnly.FromDateTime(DateTime.UtcNow)
        };

        // 执行并验证：无效时间格式应抛出异常
        var act = async () => await _service.CreatePlanAsync(child.Id, request);
        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage($"时间格式错误，正确格式如 08:00: 25:00*");
    }

    [Fact]
    public async Task UpdatePlanAsync_ShouldUpdate()
    {
        // 准备：创建用药计划
        var (elder, child, _) = await CreateTestDataAsync();
        var plan = new MedicationPlan
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            MedicineName = "降压药",
            Dosage = "50mg",
            Frequency = Frequency.OnceDaily,
            ReminderTimes = "[\"07:00\"]",
            StartDate = DateOnly.FromDateTime(DateTime.UtcNow),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.MedicationPlans.Add(plan);
        await _context.SaveChangesAsync();

        var updateRequest = new UpdateMedicationPlanRequest
        {
            MedicineName = "降压药（更新）",
            Dosage = "75mg",
            ReminderTimes = ["07:00", "19:00"]
        };

        // 执行：更新用药计划
        var result = await _service.UpdatePlanAsync(plan.Id, child.Id, updateRequest);

        // 验证：计划信息已更新
        result.Should().NotBeNull();
        result.MedicineName.Should().Be("降压药（更新）");
        result.Dosage.Should().Be("75mg");
        result.ReminderTimes.Should().BeEquivalentTo(["07:00", "19:00"]);
        result.Frequency.Should().Be(Frequency.OnceDaily); // 未修改的字段保持原值
    }

    [Fact]
    public async Task DeletePlanAsync_ShouldSoftDelete()
    {
        // 准备：创建用药计划
        var (elder, child, _) = await CreateTestDataAsync();
        var plan = new MedicationPlan
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            MedicineName = "维生素D",
            Dosage = "400IU",
            Frequency = Frequency.OnceDaily,
            ReminderTimes = "[\"09:00\"]",
            StartDate = DateOnly.FromDateTime(DateTime.UtcNow),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.MedicationPlans.Add(plan);
        await _context.SaveChangesAsync();

        // 执行：软删除计划
        await _service.DeletePlanAsync(plan.Id, child.Id);

        // 验证：计划标记为已删除，而非从数据库中移除
        var deletedPlan = await _context.MedicationPlans.FindAsync(plan.Id);
        deletedPlan.Should().NotBeNull();
        deletedPlan!.IsDeleted.Should().BeTrue();
        deletedPlan.DeletedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
    }

    [Fact]
    public async Task RecordLogAsync_ShouldRecordLog()
    {
        // 准备：创建用药计划
        var (elder, child, _) = await CreateTestDataAsync();
        var plan = new MedicationPlan
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            MedicineName = "钙片",
            Dosage = "600mg",
            Frequency = Frequency.OnceDaily,
            ReminderTimes = "[\"12:00\"]",
            StartDate = DateOnly.FromDateTime(DateTime.UtcNow),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.MedicationPlans.Add(plan);
        await _context.SaveChangesAsync();

        var request = new RecordMedicationLogRequest
        {
            PlanId = plan.Id,
            Status = MedicationStatus.Taken,
            ScheduledAt = DateTime.UtcNow.Date.AddHours(12),
            TakenAt = DateTime.UtcNow,
            Note = "饭后服用"
        };

        // 执行：记录服药日志
        var result = await _service.RecordLogAsync(child.Id, request);

        // 验证：日志记录正确
        result.Should().NotBeNull();
        result.PlanId.Should().Be(plan.Id);
        result.MedicineName.Should().Be("钙片");
        result.Status.Should().Be(MedicationStatus.Taken);
        result.Note.Should().Be("饭后服用");

        // 验证：数据库中存在该日志
        var logInDb = await _context.MedicationLogs.FirstOrDefaultAsync(l => l.Id == result.Id);
        logInDb.Should().NotBeNull();
        logInDb!.Status.Should().Be(MedicationStatus.Taken);
    }

    [Fact]
    public async Task GetTodayPendingAsync_ShouldReturnPending()
    {
        // 准备：创建今日激活的用药计划
        var (elder, child, _) = await CreateTestDataAsync();
        var today = DateOnly.FromDateTime(DateTime.UtcNow);

        var plan = new MedicationPlan
        {
            Id = Guid.NewGuid(),
            ElderId = elder.Id,
            MedicineName = "感冒药",
            Dosage = "10ml",
            Frequency = Frequency.ThreeTimesDaily,
            ReminderTimes = "[\"08:00\",\"14:00\",\"20:00\"]",
            StartDate = today,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.MedicationPlans.Add(plan);
        await _context.SaveChangesAsync();

        // 执行：获取今日待服药列表
        var result = await _service.GetTodayPendingAsync(elder.Id);

        // 验证：返回所有提醒时间点（无服药记录时状态为 Missed）
        result.Should().HaveCount(3);
        result.Should().OnlyContain(l => l.MedicineName == "感冒药");
        result.Should().OnlyContain(l => l.ElderId == elder.Id);
        // 无记录的时间点状态应为 Missed
        result.Should().OnlyContain(l => l.Status == MedicationStatus.Missed);
    }

    [Fact]
    public async Task GetTodayPendingAsync_ShouldReturnEmpty_WhenNoActivePlans()
    {
        // 准备：创建老人但不创建任何用药计划
        var (elder, _, _) = await CreateTestDataAsync();

        // 执行：获取今日待服药列表
        var result = await _service.GetTodayPendingAsync(elder.Id);

        // 验证：无活跃计划时返回空列表
        result.Should().BeEmpty();
    }

    [Fact]
    public async Task CreatePlanAsync_ShouldThrow_WhenUserNotFamilyMember()
    {
        // 准备：创建老人和一个陌生子女（不在同一家庭）
        var (elder, _, _) = await CreateTestDataAsync();
        var stranger = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = "13900009999",
            PasswordHash = "hash",
            RealName = "陌生人",
            Role = UserRole.Child
        };
        _context.Users.Add(stranger);
        await _context.SaveChangesAsync();

        var request = new CreateMedicationPlanRequest
        {
            ElderId = elder.Id,
            MedicineName = "测试药品",
            Dosage = "1片",
            Frequency = Frequency.OnceDaily,
            ReminderTimes = ["08:00"],
            StartDate = DateOnly.FromDateTime(DateTime.Today),
            EndDate = DateOnly.FromDateTime(DateTime.Today.AddDays(30))
        };

        // 执行并验证：非家庭成员应抛出权限异常
        var act = async () => await _service.CreatePlanAsync(stranger.Id, request);
        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }
}
