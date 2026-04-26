using CareForTheOld.Common.Constants;
using CareForTheOld.Services.Interfaces;
using System.Text;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 环境变量密钥提供者（生产环境使用）
///
/// 从环境变量 JWT_SECRET_KEY 中读取 JWT 密钥。
/// 生产环境密钥不应存储在配置文件中，通过环境变量或密钥管理服务注入更安全。
/// 支持未来扩展为从 Key Vault 获取密钥（如 Azure Key Vault、AWS Secrets Manager）。
/// </summary>
public class EnvironmentKeyProvider : IKeyProvider
{
    /// <summary>
    /// 环境变量名
    /// </summary>
    private const string _envVarName = "JWT_SECRET_KEY";

    /// <inheritdoc />
    public Task<byte[]> GetSigningKeyAsync()
    {
        var key = Environment.GetEnvironmentVariable(_envVarName);

        if (string.IsNullOrWhiteSpace(key) || key.Length < 32)
        {
            throw new InvalidOperationException(ErrorMessages.Configuration.JwtSecretKeyNotConfiguredInEnv);
        }

        return Task.FromResult(Encoding.UTF8.GetBytes(key));
    }
}
