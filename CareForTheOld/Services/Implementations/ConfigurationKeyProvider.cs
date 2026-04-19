using CareForTheOld.Services.Interfaces;
using Microsoft.Extensions.Configuration;
using System.Text;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 配置文件密钥提供者（开发/测试环境使用）
///
/// 从 appsettings.json 或 IConfiguration 中读取 JWT 密钥。
/// 仅适用于开发和测试环境，生产环境应使用 EnvironmentKeyProvider 或 KeyVaultKeyProvider。
/// </summary>
public class ConfigurationKeyProvider : IKeyProvider
{
    private readonly IConfiguration _configuration;

    public ConfigurationKeyProvider(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    /// <inheritdoc />
    public Task<byte[]> GetSigningKeyAsync()
    {
        var key = _configuration["Jwt:Key"];

        if (string.IsNullOrWhiteSpace(key) || key.Length < 32)
        {
            throw new InvalidOperationException(
                "JWT 密钥未配置或长度不足 32 字符。" +
                "请通过配置文件 Jwt:Key 节点设置，或切换至 EnvironmentKeyProvider。");
        }

        return Task.FromResult(Encoding.UTF8.GetBytes(key));
    }
}
