namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 缓存服务接口
/// </summary>
public interface ICacheService
{
    /// <summary>获取缓存，不存在则返回 null</summary>
    Task<T?> GetAsync<T>(string key) where T : class;

    /// <summary>设置缓存</summary>
    Task SetAsync<T>(string key, T value, TimeSpan? expiration = null) where T : class;

    /// <summary>删除缓存</summary>
    Task RemoveAsync(string key);

    /// <summary>按前缀删除缓存</summary>
    Task RemoveByPrefixAsync(string prefix);
}
