using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 健康异常预警服务实现
/// </summary>
public class HealthAlertService : IHealthAlertService
{
    private readonly AppDbContext _context;
    private readonly INotificationService _notificationService;
    private readonly IFamilyService _familyService;
    private readonly ILogger<HealthAlertService> _logger;

    public HealthAlertService(AppDbContext context, INotificationService notificationService, IFamilyService familyService, ILogger<HealthAlertService> logger)
    {
        _context = context;
        _notificationService = notificationService;
        _familyService = familyService;
        _logger = logger;
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
    public async Task SendAlertToChildrenAsync(Guid elderId, HealthRecord record, string alertMessage, CancellationToken cancellationToken = default)
    {
        // 单次投影查询获取老人姓名和家庭 ID
        var elderInfo = await _context.FamilyMembers
            .Include(fm => fm.User)
            .Where(fm => fm.UserId == elderId)
            .Select(fm => new { fm.FamilyId, ElderName = fm.User != null ? fm.User.RealName : string.Empty })
            .FirstOrDefaultAsync(cancellationToken);

        if (elderInfo == null || string.IsNullOrEmpty(elderInfo.ElderName)) return;

        // 使用统一方法获取子女 ID
        var childIds = await _familyService.GetChildUserIdsAsync(elderInfo.FamilyId, cancellationToken);
        if (childIds is not { Count: > 0 }) return;

        var elderName = elderInfo.ElderName;

        // 构建通知内容
        var typeLabel = record.Type.GetLabel();
        var valueDisplay = GetDisplayValue(record);

        await _notificationService.SendToUsersAsync(
            childIds,
            AppConstants.NotificationTypes.HealthAlert,
            new
            {
                Title = NotificationMessages.Health.AnomalyAlertTitle,
                Content = string.Format(NotificationMessages.Health.AnomalyAlertContentTemplate, elderName, typeLabel, valueDisplay, alertMessage),
                ElderId = elderId,
                ElderName = elderName,
                HealthType = record.Type,
                RecordId = record.Id,
                RecordedAt = record.RecordedAt,
                AlertLevel = GetAlertLevel(record.Type, alertMessage)
            },
            cancellationToken
        );

        _logger.LogInformation("已向 {Count} 位子女发送健康异常预警：老人 {ElderId}，类型 {HealthType}，预警 {Alert}",
            childIds.Count, elderId, record.Type, alertMessage);
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
        if (systolic > AppConstants.HealthThresholds.BloodPressureSystolicMax ||
            diastolic > AppConstants.HealthThresholds.BloodPressureDiastolicMax)
        {
            if (systolic >= AppConstants.HealthThresholds.BloodPressureCriticalHighSystolic ||
                diastolic >= AppConstants.HealthThresholds.BloodPressureCriticalHighDiastolic)
                return HealthAlertMessages.BloodPressure.CriticalHigh;
            if (systolic >= AppConstants.HealthThresholds.BloodPressureModerateHighSystolic ||
                diastolic >= AppConstants.HealthThresholds.BloodPressureModerateHighDiastolic)
                return HealthAlertMessages.BloodPressure.ModerateHigh;
            return HealthAlertMessages.BloodPressure.MildHigh;
        }

        // 低血压判断
        if (systolic < AppConstants.HealthThresholds.BloodPressureSystolicMin ||
            diastolic < AppConstants.HealthThresholds.BloodPressureDiastolicMin)
        {
            if (systolic < AppConstants.HealthThresholds.BloodPressureCriticalLowSystolic ||
                diastolic < AppConstants.HealthThresholds.BloodPressureCriticalLowDiastolic)
                return HealthAlertMessages.BloodPressure.CriticalLow;
            return HealthAlertMessages.BloodPressure.MildLow;
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
        if (bloodSugar > AppConstants.HealthThresholds.BloodSugarMax)
        {
            if (bloodSugar >= AppConstants.HealthThresholds.BloodSugarCriticalHigh)
                return HealthAlertMessages.BloodSugar.CriticalHigh;
            if (bloodSugar >= AppConstants.HealthThresholds.BloodSugarModerateHigh)
                return HealthAlertMessages.BloodSugar.ModerateHigh;
            return HealthAlertMessages.BloodSugar.MildHigh;
        }

        // 低血糖判断
        if (bloodSugar < AppConstants.HealthThresholds.BloodSugarMin)
        {
            if (bloodSugar < AppConstants.HealthThresholds.BloodSugarCriticalLow)
                return HealthAlertMessages.BloodSugar.CriticalLow;
            return HealthAlertMessages.BloodSugar.MildLow;
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
        if (heartRate > AppConstants.HealthThresholds.HeartRateMax)
        {
            if (heartRate >= AppConstants.HealthThresholds.HeartRateCriticalHigh)
                return HealthAlertMessages.HeartRate.CriticalHigh;
            return HealthAlertMessages.HeartRate.MildHigh;
        }

        // 心率过慢
        if (heartRate < AppConstants.HealthThresholds.HeartRateMin)
        {
            if (heartRate < AppConstants.HealthThresholds.HeartRateCriticalLow)
                return HealthAlertMessages.HeartRate.CriticalLow;
            return HealthAlertMessages.HeartRate.MildLow;
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
        if (temperature > AppConstants.HealthThresholds.TemperatureMax)
        {
            if (temperature >= AppConstants.HealthThresholds.TemperatureCriticalHigh)
                return HealthAlertMessages.Temperature.CriticalHigh;
            if (temperature >= AppConstants.HealthThresholds.TemperatureModerateHigh)
                return HealthAlertMessages.Temperature.ModerateHigh;
            return HealthAlertMessages.Temperature.MildHigh;
        }

        // 体温过低判断
        if (temperature < AppConstants.HealthThresholds.TemperatureMin)
        {
            if (temperature < AppConstants.HealthThresholds.TemperatureCriticalLow)
                return HealthAlertMessages.Temperature.CriticalLow;
            return HealthAlertMessages.Temperature.MildLow;
        }

        return null;
    }

    /// <summary>
    /// 获取健康数据显示值
    /// </summary>
    private static string GetDisplayValue(HealthRecord record)
    {
        return record.Type switch
        {
            HealthType.BloodPressure => $"{record.Systolic}/{record.Diastolic} {AppConstants.HealthUnits.BloodPressure}",
            HealthType.BloodSugar => $"{record.BloodSugar} {AppConstants.HealthUnits.BloodSugar}",
            HealthType.HeartRate => $"{record.HeartRate} {AppConstants.HealthUnits.HeartRate}",
            HealthType.Temperature => $"{record.Temperature} {AppConstants.HealthUnits.Temperature}",
            _ => ""
        };
    }

    /// <summary>
    /// 根据异常类型获取预警等级
    /// </summary>
    private static string GetAlertLevel(HealthType type, string alertMessage)
    {
        // 严重异常
        if (alertMessage.Contains(HealthAlertMessages.SeverityKeywords.ImmediateTreatment) || alertMessage.Contains(HealthAlertMessages.SeverityKeywords.Severe))
            return AppConstants.AlertLevels.Critical;

        // 中度异常
        if (alertMessage.Contains(HealthAlertMessages.SeverityKeywords.PromptTreatment) || alertMessage.Contains(HealthAlertMessages.SeverityKeywords.TimelyTreatment))
            return AppConstants.AlertLevels.Warning;

        // 轻度异常
        return AppConstants.AlertLevels.Caution;
    }
}