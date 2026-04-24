using CareForTheOld.Services.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 阿里云短信服务实现（国内首选）
///
/// 使用阿里云短信 API 发送告警短信，适用于国内用户。
/// 需配置：AccessKeyId、AccessKeySecret、SignName、TemplateCode
/// 注意：实际发送需要安装 AlibabaCloud.SDK.Dysmsapi20170525 NuGet 包，
///       本实现为简化版本，生产环境需接入真实 SDK。
/// </summary>
public class AliyunSmsService : ISmsService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<AliyunSmsService> _logger;

    public string ServiceName => "Aliyun";

    public AliyunSmsService(IConfiguration configuration, ILogger<AliyunSmsService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<(bool Success, string? ErrorMessage)> SendAsync(string phoneNumber, string content)
    {
        // 配置检查
        var accessKeyId = _configuration["Sms:Aliyun:AccessKeyId"];
        var accessKeySecret = _configuration["Sms:Aliyun:AccessKeySecret"];
        var signName = _configuration["Sms:Aliyun:SignName"];
        var templateCode = _configuration["Sms:Aliyun:TemplateCode"];

        if (string.IsNullOrEmpty(accessKeyId) || string.IsNullOrEmpty(accessKeySecret))
        {
            _logger.LogWarning("[阿里云短信] 配置缺失，AccessKeyId 或 AccessKeySecret 未设置");
            return (false, "短信服务配置缺失");
        }

        try
        {
            // 生产环境应使用阿里云 SDK：
            // var client = new DysmsapiClient(accessKeyId, accessKeySecret);
            // var request = new SendSmsRequest { PhoneNumbers = phoneNumber, SignName = signName, TemplateCode = templateCode, TemplateParam = JsonSerializer.Serialize(templateParams) };
            // var response = await client.SendSmsAsync(request);
            // return response.Code == "OK" ? (true, null) : (false, response.Message);

            // 开发环境模拟发送（实际接入 SDK 后替换）
            _logger.LogInformation("[阿里云短信] 模拟发送: 手机号={Phone}, 内容={Content}", phoneNumber, content);

            // 模拟成功发送
            return (true, null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[阿里云短信] 发送失败: 手机号={Phone}", phoneNumber);
            return (false, ex.Message);
        }
    }
}