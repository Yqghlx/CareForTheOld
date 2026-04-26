using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.GeoFences;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

/// <summary>
/// 电子围栏控制器（仅子女可操作）
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/geofence")]
[Authorize(Roles = "Child")]
[EnableRateLimiting("GeneralPolicy")]
public class GeoFenceController : ControllerBase
{
    private readonly IGeoFenceService _geoFenceService;
    private readonly IFamilyService _familyService;

    public GeoFenceController(IGeoFenceService geoFenceService, IFamilyService familyService)
    {
        _geoFenceService = geoFenceService;
        _familyService = familyService;
    }

    /// <summary>
    /// 创建电子围栏
    /// </summary>
    [HttpPost]
    public async Task<ApiResponse<GeoFenceResponse>> CreateFence([FromBody] CreateGeoFenceRequest request)
    {
        var userId = this.GetUserId();
        var result = await _geoFenceService.CreateFenceAsync(userId, request);
        return ApiResponse<GeoFenceResponse>.Ok(result, "围栏创建成功");
    }

    /// <summary>
    /// 获取老人的电子围栏（需验证与老人是同一家庭成员）
    /// </summary>
    [HttpGet("elder/{elderId}")]
    public async Task<ApiResponse<GeoFenceResponse?>> GetElderFence(Guid elderId)
    {
        // 验证请求的子女与目标老人属于同一家庭
        var userId = this.GetUserId();
        var userFamilyId = await _familyService.GetMyFamilyAsync(userId);
        var elderFamilyId = await _familyService.GetMyFamilyAsync(elderId);
        if (userFamilyId == null || elderFamilyId == null || userFamilyId.Id != elderFamilyId.Id)
            return ApiResponse<GeoFenceResponse?>.Fail(ErrorMessages.GeoFence.NoPermissionToView);

        var result = await _geoFenceService.GetElderFenceAsync(elderId);
        return ApiResponse<GeoFenceResponse?>.Ok(result);
    }

    /// <summary>
    /// 更新电子围栏
    /// </summary>
    [HttpPut("{id}")]
    public async Task<ApiResponse<GeoFenceResponse>> UpdateFence(Guid id, [FromBody] CreateGeoFenceRequest request)
    {
        var userId = this.GetUserId();
        var result = await _geoFenceService.UpdateFenceAsync(id, userId, request);
        return ApiResponse<GeoFenceResponse>.Ok(result, "围栏更新成功");
    }

    /// <summary>
    /// 删除电子围栏
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<ApiResponse<object>> DeleteFence(Guid id)
    {
        var userId = this.GetUserId();
        await _geoFenceService.DeleteFenceAsync(id, userId);
        return ApiResponse<object>.Ok(null!, "围栏删除成功");
    }
}
