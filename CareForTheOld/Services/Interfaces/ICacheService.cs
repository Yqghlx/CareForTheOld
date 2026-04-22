namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 缓存服务接口
/// </summary>
public interface ICacheService
{
    /// <summary>获取缓存，不存在则返回 null</summary>
    Task<T?> GetAsync<T>(string key) where T : class;

    /// <summary>获取或创建缓存（带防击穿保护，factory 允许返回 null 表示无数据）</summary>
    Task<T?> GetOrCreateAsync<T>(string key, Func<Task<T?>> factory, TimeSpan? expiration = null) where T : class;

    /// <summary>设置缓存</summary>
    Task SetAsync<T>(string key, T value, TimeSpan? expiration = null) where T : class;

    /// <summary>删除缓存</summary>
    Task RemoveAsync(string key);

    /// <summary>按前缀删除缓存</summary>
    Task RemoveByPrefixAsync(string prefix);
}
