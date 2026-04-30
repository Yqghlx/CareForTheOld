using Aliyun.OSS;
using CareForTheOld.Common.Constants;
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
            ?? throw new InvalidOperationException(ErrorMessages.Oss.EndpointNotConfigured);
        var accessKeyId = Environment.GetEnvironmentVariable("OSS_ACCESS_KEY_ID")
            ?? throw new InvalidOperationException(ErrorMessages.Oss.AccessKeyIdNotConfigured);
        var accessKeySecret = Environment.GetEnvironmentVariable("OSS_ACCESS_KEY_SECRET")
            ?? throw new InvalidOperationException(ErrorMessages.Oss.AccessKeySecretNotConfigured);
        _bucketName = Environment.GetEnvironmentVariable("OSS_BUCKET_NAME")
            ?? throw new InvalidOperationException(ErrorMessages.Oss.BucketNameNotConfigured);

        // 构建公开访问的 baseUrl（假设 bucket 已设置为公开读）
        // 格式：https://{bucketName}.{endpoint-domain}/
        var endpointDomain = endpoint.Replace("https://", "").Replace("http://", "");
        _baseUrl = $"https://{_bucketName}.{endpointDomain}/";

        _client = new OssClient(endpoint, accessKeyId, accessKeySecret);

        _logger.LogInformation("OSS 文件存储服务已初始化：Bucket={BucketName}, BaseUrl={BaseUrl}", _bucketName, _baseUrl);
    }

    /// <inheritdoc />
    public async Task<string> UploadAsync(string directory, string fileName, Stream stream, string contentType, CancellationToken cancellationToken = default)
    {
        // 清理文件名，防止路径遍历和非法字符
        fileName = SanitizeFileName(fileName);
        directory = SanitizePathSegment(directory);

        // OSS 对象键格式：directory/filename（不含前导斜杠）
        var objectKey = $"{directory}/{fileName}";

        try
        {
            // 阿里云 OSS SDK 仅提供同步 API，使用 Task.Run 避免阻塞调用线程
            // 注意：stream 的生命周期由调用方管理，确保在此方法返回前不会 Dispose
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
    public async Task<string?> GetUrlAsync(string directory, string fileName, CancellationToken cancellationToken = default)
    {
        fileName = SanitizeFileName(fileName);
        directory = SanitizePathSegment(directory);

        // OSS 对象键格式
        var objectKey = $"{directory}/{fileName}";

        try
        {
            // 检查对象是否存在（使用 await 避免阻塞线程）
            var exists = await Task.Run(() => _client.DoesObjectExist(_bucketName, objectKey));
            if (exists)
            {
                return $"{_baseUrl}{objectKey}";
            }
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "检查文件存在失败：{ObjectKey}", objectKey);
            return null;
        }
    }

    /// <inheritdoc />
    public async Task DeleteAsync(string fileUrl, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrEmpty(fileUrl))
            return;

        // 仅允许删除本服务的 URL，防止 SSRF
        if (!fileUrl.StartsWith(_baseUrl))
            return;

        // 从 URL 解析 objectKey：https://bucket.endpoint/directory/file → directory/file
        try
        {
            var objectKey = fileUrl[_baseUrl.Length..].TrimStart('/');

            // 验证 objectKey 不包含路径遍历
            if (objectKey.Contains(".."))
                return;

            await Task.Run(() => _client.DeleteObject(_bucketName, objectKey));
            _logger.LogInformation("文件删除成功：{ObjectKey}", objectKey);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "文件删除失败：{FileUrl}", fileUrl);
        }
    }

    /// <summary>
    /// 清理文件名：去除路径遍历字符和非法字符，只保留安全字符
    /// </summary>
    private static string SanitizeFileName(string fileName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName, nameof(fileName));

        // 只取文件名部分（去除任何路径前缀）
        fileName = Path.GetFileName(fileName);

        // 替换空格和潜在危险字符
        foreach (var c in Path.GetInvalidFileNameChars())
        {
            fileName = fileName.Replace(c, '_');
        }

        // 移除路径遍历尝试
        fileName = fileName.Replace("..", "").TrimStart('.', '/', '\\');

        return fileName;
    }

    /// <summary>
    /// 清理路径段：只允许字母、数字、连字符、下划线
    /// </summary>
    private static string SanitizePathSegment(string segment)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(segment, nameof(segment));

        // 移除路径遍历和分隔符
        segment = segment.Replace("..", "").Replace("/", "").Replace("\\", "").Trim();

        return segment;
    }
}