namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 密钥提供者抽象接口
///
/// 封装 JWT 签名密钥的获取逻辑，支持多种密钥来源：
/// - 开发环境：从配置文件读取（ConfigurationKeyProvider）
/// - 生产环境：从环境变量读取（EnvironmentKeyProvider）
/// - 未来可扩展：从 Azure Key Vault / AWS Secrets Manager 获取（KeyVaultKeyProvider）
///
/// 实现了密钥管理与启动代码的解耦，便于在不修改 Program.cs 的情况下切换密钥来源。
/// </summary>
public interface IKeyProvider
{
    /// <summary>
    /// 获取 JWT 签名密钥
    /// </summary>
    /// <returns>密钥的字节数组</returns>
    /// <exception cref="InvalidOperationException">密钥未配置或长度不足</exception>
    Task<byte[]> GetSigningKeyAsync();
}
