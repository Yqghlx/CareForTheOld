using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 健康异常预警服务实现
/// </summary>
public class HealthAlertService : IHealthAlertService
{
    private readonly AppDbContext _context;
    private readonly INotificationService _notificationService;

    /// <summary>
    /// 血压正常范围（mmHg）
    /// </summary>
    private const int BloodPressureSystolicMin = 90;
    private const int BloodPressureSystolicMax = 140;
    private const int BloodPressureDiastolicMin = 60;
    private const int BloodPressureDiastolicMax = 90;

    /// <summary>
    /// 血糖正常范围（mmol/L，空腹）
    /// </summary>
    private const decimal BloodSugarMin = 3.9m;
    private const decimal BloodSugarMax = 6.1m;

    /// <summary>
    /// 心率正常范围（次/分）
    /// </summary>
    private const int HeartRateMin = 60;
    private const int HeartRateMax = 100;

    /// <summary>
    /// 体温正常范围（°C）
    /// </summary>
    private const decimal TemperatureMin = 36.0m;
    private const decimal TemperatureMax = 37.3m;

    public HealthAlertService(AppDbContext context, INotificationService notificationService)
    {
        _context = context;
        _notificationService = notificationService;
    }

    /// <summary>
    /// 检查健康记录是否存在异常
    /// </summary>
    public string? CheckAbnormal(HealthRecord record)
    {
        return record.Type switch
        {
            HealthType.BloodPressure => CheckBloodPressure(record),
            HealthType.BloodSugar => CheckBloodSugar(record),
            HealthType.HeartRate => CheckHeartRate(record),
            HealthType.Temperature => CheckTemperature(record),
            _ => null
        };
    }

    /// <summary>
    /// 发送异常预警通知给老人的子女
    /// </summary>
    public async Task SendAlertToChildrenAsync(Guid elderId, HealthRecord record, string alertMessage)
    {
        // 获取老人所在的家庭
        var familyMember = await _context.FamilyMembers
            .FirstOrDefaultAsync(fm => fm.UserId == elderId);

        if (familyMember == null) return; // 老人没有加入家庭，无法通知

        // 获取家庭中的子女成员
        var children = await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.FamilyId == familyMember.FamilyId && fm.Role == UserRole.Child)
            .ToListAsync();

        if (children.Count == 0) return; // 没有子女成员

        // 获取老人姓名
        var elder = await _context.Users.FindAsync(elderId);
        var elderName = elder?.RealName ?? "老人";

        // 构建通知内容
        var typeLabel = GetTypeLabel(record.Type);
        var valueDisplay = GetDisplayValue(record);

        if (children.Count > 0)
        {
            await _notificationService.SendToUsersAsync(
                children.Select(c => c.UserId),
                "HealthAlert",
                new
                {
                    Title = $"健康异常预警",
                    Content = $"{elderName}的{typeLabel}数据异常：{valueDisplay}。{alertMessage}请及时关注。",
                    ElderId = elderId,
                    ElderName = elderName,
                    HealthType = record.Type,
                    RecordId = record.Id,
                    RecordedAt = record.RecordedAt,
                    AlertLevel = GetAlertLevel(record.Type, alertMessage)
                }
            );
        }
    }

    /// <summary>
    /// 检查血压是否异常
    /// </summary>
    private static string? CheckBloodPressure(HealthRecord record)
    {
        if (record.Systolic == null || record.Diastolic == null) return null;

        var systolic = record.Systolic.Value;
        var diastolic = record.Diastolic.Value;

        // 高血压判断
        if (systolic > BloodPressureSystolicMax || diastolic > BloodPressureDiastolicMax)
        {
            if (systolic >= 180 || diastolic >= 120)
                return "血压严重偏高，建议立即就医！";
            if (systolic >= 160 || diastolic >= 100)
                return "血压偏高（中度高血压），建议尽快就医检查。";
            return "血压偏高，建议注意休息并监测。";
        }

        // 低血压判断
        if (systolic < BloodPressureSystolicMin || diastolic < BloodPressureDiastolicMin)
        {
            if (systolic < 80 || diastolic < 50)
                return "血压严重偏低，建议立即就医！";
            return "血压偏低，建议注意营养补充。";
        }

        return null;
    }

    /// <summary>
    /// 检查血糖是否异常
    /// </summary>
    private static string? CheckBloodSugar(HealthRecord record)
    {
        if (record.BloodSugar == null) return null;

        var bloodSugar = record.BloodSugar.Value;

        // 高血糖判断
        if (bloodSugar > BloodSugarMax)
        {
            if (bloodSugar >= 11.1m)
                return "血糖严重偏高（可能为糖尿病），建议立即就医！";
            if (bloodSugar >= 7.0m)
                return "血糖偏高，建议尽快就医检查。";
            return "血糖偏高，建议注意饮食控制。";
        }

        // 低血糖判断
        if (bloodSugar < BloodSugarMin)
        {
            if (bloodSugar < 2.8m)
                return "血糖严重偏低（低血糖危险），建议立即补充糖分！";
            return "血糖偏低，建议适当补充糖分。";
        }

        return null;
    }

    /// <summary>
    /// 检查心率是否异常
    /// </summary>
    private static string? CheckHeartRate(HealthRecord record)
    {
        if (record.HeartRate == null) return null;

        var heartRate = record.HeartRate.Value;

        // 心率过快
        if (heartRate > HeartRateMax)
        {
            if (heartRate >= 150)
                return "心率过快，建议立即就医检查！";
            return "心率偏快，建议注意休息放松。";
        }

        // 心率过慢
        if (heartRate < HeartRateMin)
        {
            if (heartRate < 40)
                return "心率过慢，建议立即就医检查！";
            return "心率偏慢，建议关注身体状况。";
        }

        return null;
    }

    /// <summary>
    /// 检查体温是否异常
    /// </summary>
    private static string? CheckTemperature(HealthRecord record)
    {
        if (record.Temperature == null) return null;

        var temperature = record.Temperature.Value;

        // 发热判断
        if (temperature > TemperatureMax)
        {
            if (temperature >= 39.0m)
                return "高烧，建议立即就医！";
            if (temperature >= 38.0m)
                return "发烧，建议及时就医检查。";
            return "低烧，建议注意休息观察。";
        }

        // 体温过低判断
        if (temperature < TemperatureMin)
        {
            if (temperature < 35.0m)
                return "体温过低，建议立即就医！";
            return "体温偏低，建议注意保暖。";
        }

        return null;
    }

    /// <summary>
    /// 获取健康类型显示名称
    /// </summary>
    private static string GetTypeLabel(HealthType type)
    {
        return type switch
        {
            HealthType.BloodPressure => "血压",
            HealthType.BloodSugar => "血糖",
            HealthType.HeartRate => "心率",
            HealthType.Temperature => "体温",
            _ => type.ToString()
        };
    }

    /// <summary>
    /// 获取健康数据显示值
    /// </summary>
    private static string GetDisplayValue(HealthRecord record)
    {
        return record.Type switch
        {
            HealthType.BloodPressure => $"{record.Systolic}/{record.Diastolic} mmHg",
            HealthType.BloodSugar => $"{record.BloodSugar} mmol/L",
            HealthType.HeartRate => $"{record.HeartRate} 次/分",
            HealthType.Temperature => $"{record.Temperature} °C",
            _ => ""
        };
    }

    /// <summary>
    /// 根据异常类型获取预警等级
    /// </summary>
    private static string GetAlertLevel(HealthType type, string alertMessage)
    {
        // 严重异常
        if (alertMessage.Contains("立即就医") || alertMessage.Contains("严重"))
            return AppConstants.AlertLevels.Critical;

        // 中度异常
        if (alertMessage.Contains("尽快就医") || alertMessage.Contains("及时就医"))
            return AppConstants.AlertLevels.Warning;

        // 轻度异常
        return AppConstants.AlertLevels.Caution;
    }
}