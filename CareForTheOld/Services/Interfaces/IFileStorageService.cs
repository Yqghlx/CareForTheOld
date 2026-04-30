namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 文件存储服务抽象接口
///
/// 将文件 IO 操作从 Web 进程中解耦，便于后续切换至云存储（OSS/S3）。
/// 开发环境使用 LocalFileStorage（本地磁盘），生产环境可替换为 CloudFileStorage。
/// </summary>
public interface IFileStorageService
{
    /// <summary>
    /// 上传文件到存储
    /// </summary>
    /// <param name="directory">存储子目录（如 "avatars"）</param>
    /// <param name="fileName">文件名（含扩展名）</param>
    /// <param name="stream">文件内容流</param>
    /// <param name="contentType">文件 MIME 类型</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>文件访问的相对 URL 路径</returns>
    Task<string> UploadAsync(string directory, string fileName, Stream stream, string contentType, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取文件的访问 URL
    /// </summary>
    /// <param name="directory">存储子目录</param>
    /// <param name="fileName">文件名</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>文件访问的相对 URL 路径；文件不存在时返回 null</returns>
    Task<string?> GetUrlAsync(string directory, string fileName, CancellationToken cancellationToken = default);

    /// <summary>
    /// 删除指定文件
    /// </summary>
    /// <param name="fileUrl">文件的完整相对 URL 路径（由 UploadAsync 返回）</param>
    /// <param name="cancellationToken">取消令牌</param>
    Task DeleteAsync(string fileUrl, CancellationToken cancellationToken = default);
}
