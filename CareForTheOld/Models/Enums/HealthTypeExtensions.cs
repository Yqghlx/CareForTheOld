using CareForTheOld.Common.Constants;

namespace CareForTheOld.Models.Enums;

/// <summary>
/// HealthType 枚举扩展方法
/// </summary>
public static class HealthTypeExtensions
{
    /// <summary>
    /// 获取健康类型的中文名称标签
    /// </summary>
    public static string GetLabel(this HealthType type) => type switch
    {
        HealthType.BloodPressure => AppConstants.HealthTypeLabels.BloodPressure,
        HealthType.BloodSugar => AppConstants.HealthTypeLabels.BloodSugar,
        HealthType.HeartRate => AppConstants.HealthTypeLabels.HeartRate,
        HealthType.Temperature => AppConstants.HealthTypeLabels.Temperature,
        _ => type.ToString()
    };
}
