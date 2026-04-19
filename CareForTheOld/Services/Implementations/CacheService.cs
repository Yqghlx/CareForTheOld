using System.Text.Json;
using CareForTheOld.Services.Interfaces;
using Microsoft.Extensions.Caching.Distributed;
using StackExchange.Redis;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 缓存服务实现（基于 IDistributedCache，支持 Redis 和内存）
/// </summary>
public class CacheService : ICacheService
{
    private readonly IDistributedCache _cache;
    private readonly ILogger<CacheService> _logger;
    private readonly IConnectionMultiplexer? _redis;

    public CacheService(
        IDistributedCache cache,
        ILogger<CacheService> logger,
        IConnectionMultiplexer? redis = null)
    {
        _cache = cache;
        _logger = logger;
        _redis = redis;
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

    /// <summary>
    /// 按前缀批量删除缓存键
    /// 优先使用 Redis SCAN 命令精确删除；未配置 Redis 时记录警告日志
    /// </summary>
    public async Task RemoveByPrefixAsync(string prefix)
    {
        if (_redis != null)
        {
            var db = _redis.GetDatabase();
            var server = _redis.GetServers().FirstOrDefault();
            if (server != null)
            {
                var keys = server.Keys(pattern: $"{prefix}*").ToArray();
                if (keys.Length > 0)
                {
                    await db.KeyDeleteAsync(keys);
                    _logger.LogInformation("已按前缀 {Prefix} 删除 {Count} 个缓存键", prefix, keys.Length);
                }
            }
        }
        else
        {
            _logger.LogWarning("未配置 Redis，无法按前缀删除缓存: {Prefix}", prefix);
        }
    }
}
