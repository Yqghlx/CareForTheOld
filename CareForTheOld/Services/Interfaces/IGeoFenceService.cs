using CareForTheOld.Models.DTOs.Requests.GeoFences;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 电子围栏服务接口
/// </summary>
public interface IGeoFenceService
{
    /// <summary>
    /// 创建电子围栏
    /// </summary>
    Task<GeoFenceResponse> CreateFenceAsync(Guid creatorId, CreateGeoFenceRequest request, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取老人的电子围栏
    /// </summary>
    Task<GeoFenceResponse?> GetElderFenceAsync(Guid elderId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 更新电子围栏
    /// </summary>
    Task<GeoFenceResponse> UpdateFenceAsync(Guid fenceId, Guid operatorId, CreateGeoFenceRequest request, CancellationToken cancellationToken = default);

    /// <summary>
    /// 删除电子围栏
    /// </summary>
    Task DeleteFenceAsync(Guid fenceId, Guid operatorId, CancellationToken cancellationToken = default);

    /// <summary>
    /// 检查用户是否超出围栏
    /// </summary>
    /// <param name="userId">用户ID</param>
    /// <param name="latitude">当前位置纬度</param>
    /// <param name="longitude">当前位置经度</param>
    /// <returns>超出围栏时返回围栏信息和超出距离，null 表示未超出或无围栏</returns>
    Task<(GeoFenceResponse? fence, double distance)?> CheckOutsideFenceAsync(Guid userId, double latitude, double longitude, CancellationToken cancellationToken = default);
}