using CareForTheOld.Common.Constants;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Hosting;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 本地文件存储服务（开发环境使用）
///
/// 将文件保存到 Web 应用的 ContentRootPath 下的 uploads 目录中，
/// 适用于单实例部署的开发和测试环境。
/// 生产环境应替换为云存储实现（如 S3/OSS），以支持多实例共享和水平扩展。
/// </summary>
public class LocalFileStorageService : IFileStorageService
{
    private readonly IWebHostEnvironment _env;
    /// <summary>
    /// 文件存储的基础目录名
    /// </summary>
    private const string _baseDirectory = "uploads";

    public LocalFileStorageService(IWebHostEnvironment env)
    {
        _env = env;
    }

    /// <inheritdoc />
    public async Task<string> UploadAsync(string directory, string fileName, Stream stream, string contentType)
    {
        // 确保目标目录存在
        var targetDir = Path.Combine(_env.ContentRootPath, _baseDirectory, directory);
        Directory.CreateDirectory(targetDir);

        var filePath = Path.GetFullPath(Path.Combine(targetDir, fileName));

        // 防止路径遍历攻击：确保最终路径在预期目录内
        var basePath = Path.GetFullPath(targetDir);
        if (!filePath.StartsWith(basePath, StringComparison.OrdinalIgnoreCase))
            throw new UnauthorizedAccessException(ErrorMessages.FileStorage.IllegalFilePath);

        // 覆盖写入（头像场景下同一用户只保留一个文件）
        using var fileStream = new FileStream(filePath, FileMode.Create);
        await stream.CopyToAsync(fileStream);

        return $"/{_baseDirectory}/{directory}/{fileName}";
    }

    /// <inheritdoc />
    public Task<string?> GetUrlAsync(string directory, string fileName)
    {
        var filePath = Path.GetFullPath(Path.Combine(_env.ContentRootPath, _baseDirectory, directory, fileName));
        var basePath = Path.GetFullPath(Path.Combine(_env.ContentRootPath, _baseDirectory));

        // 防止路径遍历：确保解析后的路径在 uploads 目录内
        if (!filePath.StartsWith(basePath, StringComparison.OrdinalIgnoreCase))
            return Task.FromResult<string?>(null);

        if (File.Exists(filePath))
        {
            return Task.FromResult<string?>($"/{_baseDirectory}/{directory}/{fileName}");
        }
        return Task.FromResult<string?>(null);
    }

    /// <inheritdoc />
    public Task DeleteAsync(string fileUrl)
    {
        // 从 URL 中解析出物理路径：/uploads/avatars/xxx.jpg → ContentRootPath/uploads/avatars/xxx.jpg
        if (string.IsNullOrEmpty(fileUrl))
            return Task.CompletedTask;

        // 移除开头的 / 分隔符
        var relativePath = fileUrl.TrimStart('/');
        var filePath = Path.GetFullPath(Path.Combine(_env.ContentRootPath, relativePath));
        var basePath = Path.GetFullPath(Path.Combine(_env.ContentRootPath, _baseDirectory));

        // 防止路径遍历攻击：确保解析后的路径在 uploads 目录内
        if (!filePath.StartsWith(basePath, StringComparison.OrdinalIgnoreCase))
            return Task.CompletedTask;

        if (File.Exists(filePath))
        {
            File.Delete(filePath);
        }

        return Task.CompletedTask;
    }
}
