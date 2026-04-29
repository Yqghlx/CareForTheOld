namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 健康报告服务接口
/// </summary>
public interface IHealthReportService
{
    /// <summary>
    /// 生成健康报告 PDF
    /// </summary>
    /// <param name="userId">用户ID</param>
    /// <param name="daysRange">报告时间范围（天数）</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>PDF 文件字节数组</returns>
    Task<byte[]> GeneratePdfReportAsync(Guid userId, int daysRange, CancellationToken cancellationToken = default);
}