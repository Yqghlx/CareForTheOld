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
    Task<LocationRecordResponse> ReportLocationAsync(Guid userId, double latitude, double longitude);

    /// <summary>
    /// 获取用户最新位置
    /// </summary>
    Task<LocationRecordResponse?> GetLatestLocationAsync(Guid userId);

    /// <summary>
    /// 获取用户位置历史
    /// </summary>
    Task<List<LocationRecordResponse>> GetLocationHistoryAsync(Guid userId, int skip = 0, int limit = 50);

    /// <summary>
    /// 获取家庭成员最新位置（子女查看老人）
    /// </summary>
    Task<LocationRecordResponse?> GetFamilyMemberLatestLocationAsync(Guid familyId, Guid memberId);

    /// <summary>
    /// 获取家庭成员位置历史（子女查看老人）
    /// </summary>
    Task<List<LocationRecordResponse>> GetFamilyMemberLocationHistoryAsync(Guid familyId, Guid memberId, int skip = 0, int limit = 50);
}