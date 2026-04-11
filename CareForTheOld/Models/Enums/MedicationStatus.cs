namespace CareForTheOld.Models.Enums;

/// <summary>
/// 服药状态枚举
/// </summary>
public enum MedicationStatus
{
    /// <summary>已服</summary>
    Taken = 0,

    /// <summary>跳过</summary>
    Skipped = 1,

    /// <summary>漏服</summary>
    Missed = 2
}