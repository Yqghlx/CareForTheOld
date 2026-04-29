using CareForTheOld.Common.Constants;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 位置服务接口
/// </summary>
public interface ILocationService
{
    /// <summary>
    /// 上报位置
    /// </summary>
    /// <param name="userId">用户 ID</param>
    /// <param name="latitude">纬度</param>
    /// <param name="longitude">经度</param>
    /// <param name="accuracy">GPS 定位精度（米），超过 100 米时跳过围栏检查</param>
    /// <param name="cancellationToken">取消令牌</param>
    Task<LocationRecordResponse> ReportLocationAsync(Guid userId, double latitude, double longitude, double? accuracy = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取用户最新位置
    /// </summary>
    /// <param name="userId">用户 ID</param>
    /// <param name="cancellationToken">取消令牌</param>
    Task<LocationRecordResponse?> GetLatestLocationAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取用户位置历史
    /// </summary>
    /// <param name="userId">用户 ID</param>
    /// <param name="skip">跳过记录数</param>
    /// <param name="limit">返回记录数</param>
    /// <param name="cancellationToken">取消令牌</param>
    Task<List<LocationRecordResponse>> GetLocationHistoryAsync(Guid userId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取家庭成员最新位置（子女查看老人）
    /// </summary>
    /// <param name="familyId">家庭 ID</param>
    /// <param name="memberId">家庭成员 ID</param>
    /// <param name="cancellationToken">取消令牌</param>
    Task<LocationRecordResponse?> GetFamilyMemberLatestLocationAsync(Guid familyId, Guid memberId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取家庭成员位置历史（子女查看老人）
    /// </summary>
    /// <param name="familyId">家庭 ID</param>
    /// <param name="memberId">家庭成员 ID</param>
    /// <param name="skip">跳过记录数</param>
    /// <param name="limit">返回记录数</param>
    /// <param name="cancellationToken">取消令牌</param>
    Task<List<LocationRecordResponse>> GetFamilyMemberLocationHistoryAsync(Guid familyId, Guid memberId, int skip = AppConstants.Pagination.DefaultSkip, int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default);
}