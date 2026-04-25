using Bogus;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;

namespace CareForTheOld.Tests.Helpers;

/// <summary>
/// 测试数据构建器，封装常用实体的创建方法。
/// 使用 Bogus 生成随机且合理的测试数据，所有方法仅创建实体对象，不执行数据库保存。
/// </summary>
public static class TestDataBuilder
{
    /// <summary>
    /// 全局 Faker 实例，用于生成各类随机数据。
    /// 设定 Locale 为 "zh_CN" 以生成中文名等本地化数据。
    /// </summary>
    private static readonly Faker FakerInstance = new("zh_CN");

    /// <summary>
    /// 创建老人用户实体。
    /// Role 固定为 Elder，随机生成手机号、中文姓名、出生日期等信息。
    /// </summary>
    /// <returns>已填充默认值的老人用户实体</returns>
    public static User CreateElderUser()
    {
        return new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = FakerInstance.Phone.PhoneNumber("1##########"),
            PasswordHash = FakerInstance.Random.String2(60, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./"),
            RealName = FakerInstance.Name.FullName(),
            BirthDate = GenerateBirthDate(65, 90),
            Role = UserRole.Elder,
            AvatarUrl = FakerInstance.Internet.Avatar(),
            CreatedAt = FakerInstance.Date.Past(1).ToUniversalTime(),
            UpdatedAt = FakerInstance.Date.Recent().ToUniversalTime()
        };
    }

    /// <summary>
    /// 创建子女用户实体。
    /// Role 固定为 Child，随机生成手机号、中文姓名、出生日期等信息。
    /// </summary>
    /// <returns>已填充默认值的子女用户实体</returns>
    public static User CreateChildUser()
    {
        return new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = FakerInstance.Phone.PhoneNumber("1##########"),
            PasswordHash = FakerInstance.Random.String2(60, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./"),
            RealName = FakerInstance.Name.FullName(),
            BirthDate = GenerateBirthDate(25, 50),
            Role = UserRole.Child,
            AvatarUrl = FakerInstance.Internet.Avatar(),
            CreatedAt = FakerInstance.Date.Past(1).ToUniversalTime(),
            UpdatedAt = FakerInstance.Date.Recent().ToUniversalTime()
        };
    }

    /// <summary>
    /// 创建家庭组实体。
    /// 随机生成中文家庭名称和 6 位数字邀请码。
    /// </summary>
    /// <param name="creatorId">创建者（老人）的用户ID</param>
    /// <returns>已填充默认值的家庭组实体</returns>
    public static Family CreateFamily(Guid creatorId)
    {
        return new Family
        {
            Id = Guid.NewGuid(),
            FamilyName = FakerInstance.Company.CompanyName() + "家",
            CreatorId = creatorId,
            InviteCode = FakerInstance.Random.String2(6, "0123456789"),
            CreatedAt = FakerInstance.Date.Past(1).ToUniversalTime()
        };
    }

    /// <summary>
    /// 创建家庭成员关系实体。
    /// 用于关联用户与家庭组，记录角色和与老人的关系描述。
    /// </summary>
    /// <param name="familyId">所属家庭组ID</param>
    /// <param name="userId">用户ID</param>
    /// <param name="role">成员角色（Elder 或 Child）</param>
    /// <returns>已填充默认值的家庭成员关系实体</returns>
    public static FamilyMember CreateFamilyMember(Guid familyId, Guid userId, UserRole role)
    {
        // 根据角色生成合理的关系描述
        var relation = role == UserRole.Elder
            ? "老人"
            : FakerInstance.PickRandom("儿子", "女儿", "儿媳", "女婿");

        return new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = userId,
            Role = role,
            Relation = relation,
            Status = FamilyMemberStatus.Approved
        };
    }

    /// <summary>
    /// 创建健康记录实体。
    /// 根据健康数据类型自动填充对应字段的合理随机值，其他字段置为 null。
    /// </summary>
    /// <param name="userId">所属用户ID</param>
    /// <param name="type">健康数据类型</param>
    /// <returns>已填充对应类型合理数据的健康记录实体</returns>
    public static HealthRecord CreateHealthRecord(Guid userId, HealthType type)
    {
        return new HealthRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = type,
            Systolic = type == HealthType.BloodPressure
                ? FakerInstance.Random.Int(90, 140)
                : null,
            Diastolic = type == HealthType.BloodPressure
                ? FakerInstance.Random.Int(60, 90)
                : null,
            BloodSugar = type == HealthType.BloodSugar
                ? Math.Round(FakerInstance.Random.Decimal(3.9m, 11.1m), 1)
                : null,
            HeartRate = type == HealthType.HeartRate
                ? FakerInstance.Random.Int(60, 100)
                : null,
            Temperature = type == HealthType.Temperature
                ? Math.Round(FakerInstance.Random.Decimal(36.0m, 37.5m), 1)
                : null,
            Note = FakerInstance.Lorem.Sentence(),
            RecordedAt = FakerInstance.Date.Recent(7).ToUniversalTime(),
            CreatedAt = FakerInstance.Date.Recent(7).ToUniversalTime(),
            IsDeleted = false,
            DeletedAt = null
        };
    }

    /// <summary>
    /// 创建用药计划实体。
    /// 随机生成药品名称、剂量、频率和提醒时间。
    /// </summary>
    /// <param name="elderId">关联的老人用户ID</param>
    /// <returns>已填充默认值的用药计划实体</returns>
    public static MedicationPlan CreateMedicationPlan(Guid elderId)
    {
        // 根据频率生成对应的提醒时间点 JSON
        var frequency = FakerInstance.PickRandom<Frequency>();
        var reminderTimes = GenerateReminderTimes(frequency);

        return new MedicationPlan
        {
            Id = Guid.NewGuid(),
            ElderId = elderId,
            MedicineName = FakerInstance.PickRandom(
                "阿司匹林", "降压片", "二甲双胍", "阿托伐他汀", "氨氯地平", "硝苯地平"),
            Dosage = FakerInstance.PickRandom("1片", "2片", "半片", "1粒", "10ml"),
            Frequency = frequency,
            ReminderTimes = reminderTimes,
            StartDate = DateOnly.FromDateTime(FakerInstance.Date.Past(1)),
            EndDate = DateOnly.FromDateTime(FakerInstance.Date.Future(1)),
            IsActive = true,
            CreatedAt = FakerInstance.Date.Past(1).ToUniversalTime(),
            UpdatedAt = FakerInstance.Date.Recent().ToUniversalTime(),
            IsDeleted = false,
            DeletedAt = null
        };
    }

    /// <summary>
    /// 创建刷新令牌实体。
    /// 生成随机 Token 字符串，过期时间默认为未来 7 天。
    /// </summary>
    /// <param name="userId">所属用户ID</param>
    /// <returns>已填充默认值的刷新令牌实体</returns>
    public static RefreshToken CreateRefreshToken(Guid userId)
    {
        return new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Token = FakerInstance.Random.String2(64, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
            ExpiresAt = FakerInstance.Date.Future(7).ToUniversalTime(),
            IsRevoked = false,
            IsUsed = false,
            CreatedAt = FakerInstance.Date.Recent().ToUniversalTime()
        };
    }

    /// <summary>
    /// 创建紧急呼叫实体。
    /// 默认状态为待处理（Pending），无响应者信息。
    /// </summary>
    /// <param name="elderId">发起呼叫的老人ID</param>
    /// <param name="familyId">所属家庭组ID</param>
    /// <returns>已填充默认值的紧急呼叫实体</returns>
    public static EmergencyCall CreateEmergencyCall(Guid elderId, Guid familyId)
    {
        return new EmergencyCall
        {
            Id = Guid.NewGuid(),
            ElderId = elderId,
            FamilyId = familyId,
            CalledAt = FakerInstance.Date.Recent().ToUniversalTime(),
            Status = EmergencyStatus.Pending,
            RespondedBy = null,
            RespondedAt = null,
            RespondedByRealName = null
        };
    }

    /// <summary>
    /// 创建位置记录实体。
    /// 经纬度范围限定在中国境内：纬度 18~53，经度 73~135。
    /// </summary>
    /// <param name="userId">所属用户ID</param>
    /// <returns>已填充中国境内随机坐标的位置记录实体</returns>
    public static LocationRecord CreateLocationRecord(Guid userId)
    {
        return new LocationRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Latitude = FakerInstance.Random.Double(18.0, 53.0),
            Longitude = FakerInstance.Random.Double(73.0, 135.0),
            RecordedAt = FakerInstance.Date.Recent().ToUniversalTime()
        };
    }

    /// <summary>
    /// 根据年龄范围生成合理的出生日期。
    /// </summary>
    /// <param name="minAge">最小年龄</param>
    /// <param name="maxAge">最大年龄</param>
    /// <returns>计算得到的出生日期</returns>
    private static DateOnly GenerateBirthDate(int minAge, int maxAge)
    {
        var age = FakerInstance.Random.Int(minAge, maxAge);
        var today = DateTime.Today;
        var birthYear = today.Year - age;
        var birthDate = new DateOnly(birthYear, FakerInstance.Random.Int(1, 12), FakerInstance.Random.Int(1, 28));
        return birthDate;
    }

    /// <summary>
    /// 根据用药频率生成对应的提醒时间点 JSON 字符串。
    /// 例如：每日三次生成 ["08:00","14:00","20:00"]。
    /// </summary>
    /// <param name="frequency">用药频率</param>
    /// <returns>JSON 格式的提醒时间点字符串</returns>
    private static string GenerateReminderTimes(Frequency frequency)
    {
        return frequency switch
        {
            Frequency.OnceDaily => """["08:00"]""",
            Frequency.TwiceDaily => """["08:00","20:00"]""",
            Frequency.ThreeTimesDaily => """["08:00","14:00","20:00"]""",
            Frequency.AsNeeded => """["09:00"]""",
            _ => """["08:00"]"""
        };
    }
}
