using CareForTheOld.Common.Constants;
using CareForTheOld.Services.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// Twilio 短信服务实现（国际备用）
///
/// 使用 Twilio API 发送告警短信，适用于国际用户。
/// 需配置：AccountSid、AuthToken、FromNumber
/// 注意：实际发送需要安装 Twilio NuGet 包，
///       本实现为简化版本，生产环境需接入真实 SDK。
/// </summary>
public class TwilioSmsService : ISmsService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<TwilioSmsService> _logger;

    public string ServiceName => "Twilio";

    public TwilioSmsService(IConfiguration configuration, ILogger<TwilioSmsService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<(bool Success, string? ErrorMessage)> SendAsync(string phoneNumber, string content)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(phoneNumber, nameof(phoneNumber));
        ArgumentException.ThrowIfNullOrWhiteSpace(content, nameof(content));

        // 配置检查
        var accountSid = _configuration[ConfigurationKeys.Sms.Twilio.AccountSid];
        var authToken = _configuration[ConfigurationKeys.Sms.Twilio.AuthToken];
        var fromNumber = _configuration[ConfigurationKeys.Sms.Twilio.FromNumber];

        if (string.IsNullOrEmpty(accountSid) || string.IsNullOrEmpty(authToken) || string.IsNullOrEmpty(fromNumber))
        {
            _logger.LogWarning("[Twilio短信] 配置缺失，AccountSid、AuthToken 或 FromNumber 未设置");
            return (false, ErrorMessages.Sms.ConfigMissing);
        }

        // 验证手机号格式（Twilio 需要国际格式 +86xxxxxxxxxx）
        if (!phoneNumber.StartsWith("+"))
        {
            _logger.LogWarning("[Twilio短信] 手机号格式不正确，需要国际格式（如 +8613800138000）: {Phone}", phoneNumber);
            return (false, ErrorMessages.Sms.PhoneFormatInternational);
        }

        try
        {
            // 生产环境应使用 Twilio SDK：
            // TwilioClient.Init(accountSid, authToken);
            // var message = await MessageResource.CreateAsync(
            //     to: new PhoneNumber(phoneNumber),
            //     from: new PhoneNumber(fromNumber),
            //     body: content
            // );
            // return message.Status == MessageStatus.Sent ? (true, null) : (false, message.ErrorMessage);

            // 开发环境模拟发送（实际接入 SDK 后替换）
            _logger.LogInformation("[Twilio短信] 模拟发送: 手机号={Phone}, 内容={Content}", phoneNumber, content);

            // 模拟成功发送
            return (true, null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Twilio短信] 发送失败: 手机号={Phone}", phoneNumber);
            return (false, ErrorMessages.Sms.SendFailed);
        }
    }
}