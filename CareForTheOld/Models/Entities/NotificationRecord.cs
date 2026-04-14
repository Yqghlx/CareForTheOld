namespace CareForTheOld.Models.Entities;

/// <summary>
/// 通知记录实体
/// </summary>
public class NotificationRecord
{
    public Guid Id { get; set; }

    /// <summary>
    /// 接收用户ID
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// 通知类型（如 MedicationReminder、EmergencyCall 等）
    /// </summary>
    public string Type { get; set; } = string.Empty;

    /// <summary>
    /// 通知标题
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// 通知内容
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// 是否已读
    /// </summary>
    public bool IsRead { get; set; }

    /// <summary>
    /// 创建时间
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public User User { get; set; } = null!;
}
