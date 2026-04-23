namespace CareForTheOld.Models.Entities;

/// <summary>
/// 短信发送记录实体（审计追溯）
///
/// 记录所有短信发送请求，用于监控短信服务可用性、追溯告警发送历史。
/// </summary>
public class SmsRecord
{
    public Guid Id { get; set; }

    /// <summary>
    /// 目标手机号
    /// </summary>
    public string PhoneNumber { get; set; } = string.Empty;

    /// <summary>
    /// 短信内容
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// 使用的短信服务商名称（Aliyun、Twilio 等）
    /// </summary>
    public string ServiceName { get; set; } = string.Empty;

    /// <summary>
    /// 发送是否成功
    /// </summary>
    public bool Success { get; set; }

    /// <summary>
    /// 发送失败时的错误信息
    /// </summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    /// 发送时间
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 关联的紧急呼叫 ID（可选）
    /// </summary>
    public Guid? RelatedEmergencyCallId { get; set; }
}