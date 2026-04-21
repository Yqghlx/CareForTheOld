using Aliyun.OSS;
using CareForTheOld.Services.Interfaces;
using Microsoft.Extensions.Logging;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 阿里云 OSS 文件存储服务（生产环境使用）
///
/// 将文件上传到阿里云 OSS，支持多实例共享和水平扩展。
/// 配置项：OSS_ENDPOINT、OSS_ACCESS_KEY_ID、OSS_ACCESS_KEY_SECRET、OSS_BUCKET_NAME
/// </summary>
public class OssFileStorageService : IFileStorageService
{
    private readonly OssClient _client;
    private readonly string _bucketName;
    private readonly string _baseUrl;
    private readonly ILogger<OssFileStorageService> _logger;

    /// <summary>
    /// 构造函数：从环境变量读取 OSS 配置
    /// </summary>
    public OssFileStorageService(ILogger<OssFileStorageService> logger)
    {
        _logger = logger;

        var endpoint = Environment.GetEnvironmentVariable("OSS_ENDPOINT")
            ?? throw new InvalidOperationException("OSS_ENDPOINT 环境变量未配置");
        var accessKeyId = Environment.GetEnvironmentVariable("OSS_ACCESS_KEY_ID")
            ?? throw new InvalidOperationException("OSS_ACCESS_KEY_ID 环境变量未配置");
        var accessKeySecret = Environment.GetEnvironmentVariable("OSS_ACCESS_KEY_SECRET")
            ?? throw new InvalidOperationException("OSS_ACCESS_KEY_SECRET 环境变量未配置");
        _bucketName = Environment.GetEnvironmentVariable("OSS_BUCKET_NAME")
            ?? throw new InvalidOperationException("OSS_BUCKET_NAME 环境变量未配置");

        // 构建公开访问的 baseUrl（假设 bucket 已设置为公开读）
        // 格式：https://{bucketName}.{endpoint-domain}/
        var endpointDomain = endpoint.Replace("https://", "").Replace("http://", "");
        _baseUrl = $"https://{_bucketName}.{endpointDomain}/";

        _client = new OssClient(endpoint, accessKeyId, accessKeySecret);

        _logger.LogInformation("OSS 文件存储服务已初始化：Bucket={BucketName}, BaseUrl={BaseUrl}", _bucketName, _baseUrl);
    }

    /// <inheritdoc />
    public async Task<string> UploadAsync(string directory, string fileName, Stream stream, string contentType)
    {
        // OSS 对象键格式：directory/filename（不含前导斜杠）
        var objectKey = $"{directory}/{fileName}";

        try
        {
            // 上传文件到 OSS
            var result = await Task.Run(() => _client.PutObject(_bucketName, objectKey, stream, new ObjectMetadata
            {
                ContentType = contentType
            }));

            _logger.LogInformation("文件上传成功：{ObjectKey}, ETag={ETag}", objectKey, result.ETag);

            // 返回公开访问 URL
            return $"{_baseUrl}{objectKey}";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "文件上传失败：{ObjectKey}", objectKey);
            throw;
        }
    }

    /// <inheritdoc />
    public Task<string?> GetUrlAsync(string directory, string fileName)
    {
        // OSS 对象键格式
        var objectKey = $"{directory}/{fileName}";

        try
        {
            // 检查对象是否存在
            var exists = Task.Run(() => _client.DoesObjectExist(_bucketName, objectKey)).Result;
            if (exists)
            {
                return Task.FromResult<string?>($"{_baseUrl}{objectKey}");
            }
            return Task.FromResult<string?>(null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "检查文件存在失败：{ObjectKey}", objectKey);
            return Task.FromResult<string?>(null);
        }
    }

    /// <inheritdoc />
    public async Task DeleteAsync(string fileUrl)
    {
        if (string.IsNullOrEmpty(fileUrl))
            return;

        // 从 URL 解析 objectKey：https://bucket.endpoint/directory/file → directory/file
        try
        {
            // 移除 baseUrl 前缀
            var objectKey = fileUrl.Replace(_baseUrl, "");
            if (objectKey.StartsWith("/"))
                objectKey = objectKey.Substring(1);

            await Task.Run(() => _client.DeleteObject(_bucketName, objectKey));
            _logger.LogInformation("文件删除成功：{ObjectKey}", objectKey);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "文件删除失败：{FileUrl}", fileUrl);
        }
    }
}