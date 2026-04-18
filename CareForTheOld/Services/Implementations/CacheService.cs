using System.Text.Json;
using CareForTheOld.Services.Interfaces;
using Microsoft.Extensions.Caching.Distributed;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 缓存服务实现（基于 IDistributedCache，支持 Redis 和内存）
/// </summary>
public class CacheService : ICacheService
{
    private readonly IDistributedCache _cache;
    private readonly ILogger<CacheService> _logger;

    public CacheService(IDistributedCache cache, ILogger<CacheService> logger)
    {
        _cache = cache;
        _logger = logger;
    }

    public async Task<T?> GetAsync<T>(string key) where T : class
    {
        var bytes = await _cache.GetAsync(key);
        if (bytes == null) return null;
        return JsonSerializer.Deserialize<T>(bytes);
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? expiration = null) where T : class
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(value);
        var options = new DistributedCacheEntryOptions();
        if (expiration.HasValue)
            options.AbsoluteExpirationRelativeToNow = expiration;
        else
            options.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(30);
        await _cache.SetAsync(key, bytes, options);
    }

    public async Task RemoveAsync(string key)
    {
        await _cache.RemoveAsync(key);
    }

    public async Task RemoveByPrefixAsync(string prefix)
    {
        // IDistributedCache 不支持前缀扫描，此处记录日志
        // 生产环境可使用 ConnectionMultiplexer 直接操作 Redis
        _logger.LogInformation("前缀删除请求: {Prefix}（需 Redis 原生支持）", prefix);
        await Task.CompletedTask;
    }
}
