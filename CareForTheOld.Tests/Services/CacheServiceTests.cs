using CareForTheOld.Services.Implementations;
using FluentAssertions;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using Moq;
using System.Text;
using System.Text.Json;
using Xunit;

namespace CareForTheOld.Tests.Services;

/// <summary>
/// CacheService 单元测试
/// </summary>
public class CacheServiceTests
{
    private readonly CacheService _service;
    private readonly Mock<IDistributedCache> _mockCache;
    private readonly Mock<ILogger<CacheService>> _mockLogger;

    public CacheServiceTests()
    {
        _mockCache = new Mock<IDistributedCache>();
        _mockLogger = new Mock<ILogger<CacheService>>();
        _service = new CacheService(_mockCache.Object, _mockLogger.Object);
    }

    [Fact]
    public async Task GetAsync_ShouldReturnValue_WhenCached()
    {
        // 准备：模拟缓存中存在数据
        var cachedData = new TestData { Name = "测试", Value = 42 };
        var cachedBytes = JsonSerializer.SerializeToUtf8Bytes(cachedData);
        _mockCache
            .Setup(c => c.GetAsync("test_key", default))
            .ReturnsAsync(cachedBytes);

        // 执行：获取缓存
        var result = await _service.GetAsync<TestData>("test_key");

        // 验证：返回缓存中的数据
        result.Should().NotBeNull();
        result!.Name.Should().Be("测试");
        result.Value.Should().Be(42);
    }

    [Fact]
    public async Task GetAsync_ShouldReturnNull_WhenNotCached()
    {
        // 准备：模拟缓存中不存在数据
        _mockCache
            .Setup(c => c.GetAsync("missing_key", default))
            .ReturnsAsync((byte[]?)null);

        // 执行：获取不存在的缓存
        var result = await _service.GetAsync<TestData>("missing_key");

        // 验证：返回 null
        result.Should().BeNull();
    }

    [Fact]
    public async Task SetAsync_ShouldSerializeAndStore()
    {
        // 准备
        var data = new TestData { Name = "存储测试", Value = 100 };
        var expectedBytes = JsonSerializer.SerializeToUtf8Bytes(data);
        var capturedBytes = (byte[]?)null;
        var capturedOptions = (DistributedCacheEntryOptions?)null;

        _mockCache
            .Setup(c => c.SetAsync(
                "store_key",
                It.IsAny<byte[]>(),
                It.IsAny<DistributedCacheEntryOptions>(),
                default))
            .Callback<string, byte[], DistributedCacheEntryOptions, CancellationToken>(
                (_, bytes, options, _) =>
                {
                    capturedBytes = bytes;
                    capturedOptions = options;
                })
            .Returns(Task.CompletedTask);

        var expiration = TimeSpan.FromMinutes(60);

        // 执行：设置缓存
        await _service.SetAsync("store_key", data, expiration);

        // 验证：数据被序列化并存储
        _mockCache.Verify(
            c => c.SetAsync(
                "store_key",
                It.IsAny<byte[]>(),
                It.IsAny<DistributedCacheEntryOptions>(),
                default),
            Times.Once);

        capturedBytes.Should().NotBeNull();
        var deserialized = JsonSerializer.Deserialize<TestData>(capturedBytes!);
        deserialized.Should().NotBeNull();
        deserialized!.Name.Should().Be("存储测试");
        deserialized.Value.Should().Be(100);

        // 验证：过期时间设置正确
        capturedOptions.Should().NotBeNull();
        capturedOptions!.AbsoluteExpirationRelativeToNow.Should().Be(expiration);
    }

    [Fact]
    public async Task SetAsync_ShouldUseDefaultExpiration_WhenNotSpecified()
    {
        // 准备
        var data = new TestData { Name = "默认过期", Value = 1 };
        var capturedOptions = (DistributedCacheEntryOptions?)null;

        _mockCache
            .Setup(c => c.SetAsync(
                "default_key",
                It.IsAny<byte[]>(),
                It.IsAny<DistributedCacheEntryOptions>(),
                default))
            .Callback<string, byte[], DistributedCacheEntryOptions, CancellationToken>(
                (_, _, options, _) => capturedOptions = options)
            .Returns(Task.CompletedTask);

        // 执行：不指定过期时间
        await _service.SetAsync("default_key", data);

        // 验证：使用默认30分钟过期
        capturedOptions.Should().NotBeNull();
        capturedOptions!.AbsoluteExpirationRelativeToNow.Should().Be(TimeSpan.FromMinutes(30));
    }

    [Fact]
    public async Task RemoveAsync_ShouldRemove()
    {
        // 准备
        _mockCache
            .Setup(c => c.RemoveAsync("remove_key", default))
            .Returns(Task.CompletedTask);

        // 执行：删除缓存
        await _service.RemoveAsync("remove_key");

        // 验证：RemoveAsync 被调用
        _mockCache.Verify(
            c => c.RemoveAsync("remove_key", default),
            Times.Once);
    }

    /// <summary>
    /// 测试用的数据类
    /// </summary>
    private class TestData
    {
        public string Name { get; set; } = string.Empty;
        public int Value { get; set; }
    }
}
