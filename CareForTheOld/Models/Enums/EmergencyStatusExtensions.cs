namespace CareForTheOld.Models.Enums;

/// <summary>
/// EmergencyStatus 枚举扩展方法
/// </summary>
public static class EmergencyStatusExtensions
{
    /// <summary>
    /// 获取状态的中文标签
    /// </summary>
    public static string GetLabel(this EmergencyStatus status) => status switch
    {
        EmergencyStatus.Pending => "待处理",
        EmergencyStatus.Responded => "已响应",
        _ => status.ToString()
    };
}
