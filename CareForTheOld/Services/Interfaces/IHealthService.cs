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
    Task<HealthRecordResponse> CreateRecordAsync(Guid userId, CreateHealthRecordRequest request);

    /// <summary>
    /// 获取用户的健康记录列表
    /// </summary>
    Task<List<HealthRecordResponse>> GetUserRecordsAsync(Guid userId, HealthType? type, int limit = 50);

    /// <summary>
    /// 获取家庭成员的健康记录（子女查看老人数据）
    /// </summary>
    Task<List<HealthRecordResponse>> GetFamilyMemberRecordsAsync(Guid familyId, Guid memberId, HealthType? type, int limit = 50);

    /// <summary>
    /// 获取健康数据统计
    /// </summary>
    Task<List<HealthStatsResponse>> GetUserStatsAsync(Guid userId);

    /// <summary>
    /// 删除健康记录
    /// </summary>
    Task DeleteRecordAsync(Guid userId, Guid recordId);
}