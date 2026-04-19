namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 通知记录响应 DTO
/// </summary>
public class NotificationResponse
{
    /// <summary>通知 ID</summary>
    public Guid Id { get; set; }

    /// <summary>通知类型</summary>
    public string Type { get; set; } = string.Empty;

    /// <summary>通知标题</summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>通知内容</summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>是否已读</summary>
    public bool IsRead { get; set; }

    /// <summary>创建时间</summary>
    public DateTime CreatedAt { get; set; }
}
