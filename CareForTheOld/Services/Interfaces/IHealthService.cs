using CareForTheOld.Common.Constants;
using CareForTheOld.Models.DTOs.Requests.Health;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 健康记录服务接口
/// </summary>
public interface IHealthService
{
    /// <summary>
    /// 创建健康记录
    /// </summary>
    Task<HealthRecordResponse> CreateRecordAsync(Guid userId, CreateHealthRecordRequest request, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取用户的健康记录列表
    /// </summary>
    Task<List<HealthRecordResponse>> GetUserRecordsAsync(Guid userId, HealthType? type, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取家庭成员的健康记录（子女查看老人数据）
    /// </summary>
    Task<List<HealthRecordResponse>> GetFamilyMemberRecordsAsync(Guid familyId, Guid memberId, HealthType? type, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default);

    /// <summary>
    /// 删除健康记录
    /// </summary>
    Task DeleteRecordAsync(Guid userId, Guid recordId, CancellationToken cancellationToken = default);
}