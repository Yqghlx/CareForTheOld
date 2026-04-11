namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 通知消息响应
/// </summary>
public class NotificationMessage
{
    /// <summary>通知类型</summary>
    public string Type { get; set; } = string.Empty;

    /// <summary>通知标题</summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>通知内容</summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>通知时间</summary>
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    /// <summary>附加数据</summary>
    public object? Data { get; set; }
}