namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 短信服务抽象接口
///
/// 支持多短信服务商切换（阿里云国内、Twilio 国际），用于紧急呼叫等多通道告警。
/// 开发环境可使用 Mock 实现，生产环境根据配置选择服务商。
/// </summary>
public interface ISmsService
{
    /// <summary>
    /// 发送短信
    /// </summary>
    /// <param name="phoneNumber">目标手机号（国际格式，如 +8613800138000）</param>
    /// <param name="content">短信内容</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>发送结果（成功/失败 + 错误信息）</returns>
    Task<(bool Success, string? ErrorMessage)> SendAsync(string phoneNumber, string content, CancellationToken cancellationToken = default);

    /// <summary>
    /// 服务名称（用于日志和审计标识）
    /// </summary>
    string ServiceName { get; }
}