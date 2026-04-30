using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.GeoFences;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
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
    [ProducesResponseType(typeof(ApiResponse<GeoFenceResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [EnableRateLimiting("WritePolicy")]
    public async Task<ApiResponse<GeoFenceResponse>> CreateFence([FromBody] CreateGeoFenceRequest request, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _geoFenceService.CreateFenceAsync(userId, request, cancellationToken);
        return ApiResponse<GeoFenceResponse>.Ok(result, SuccessMessages.GeoFence.CreateSuccess);
    }

    /// <summary>
    /// 获取老人的电子围栏（需验证与老人是同一家庭成员）
    /// </summary>
    [HttpGet("elder/{elderId}")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    [ProducesResponseType(typeof(ApiResponse<GeoFenceResponse?>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ApiResponse<GeoFenceResponse?>> GetElderFence(Guid elderId, CancellationToken cancellationToken = default)
    {
        // 验证请求的子女与目标老人属于同一家庭（两个独立查询并行执行）
        var userId = this.GetUserId();
        var families = await Task.WhenAll(
            _familyService.GetMyFamilyAsync(userId, cancellationToken),
            _familyService.GetMyFamilyAsync(elderId, cancellationToken));
        var userFamilyId = families[0];
        var elderFamilyId = families[1];
        if (userFamilyId == null || elderFamilyId == null || userFamilyId.Id != elderFamilyId.Id)
            return ApiResponse<GeoFenceResponse?>.Fail(ErrorMessages.GeoFence.NoPermissionToView);

        var result = await _geoFenceService.GetElderFenceAsync(elderId, cancellationToken);
        return ApiResponse<GeoFenceResponse?>.Ok(result);
    }

    /// <summary>
    /// 更新电子围栏
    /// </summary>
    [HttpPut("{id}")]
    [ProducesResponseType(typeof(ApiResponse<GeoFenceResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [EnableRateLimiting("WritePolicy")]
    public async Task<ApiResponse<GeoFenceResponse>> UpdateFence(Guid id, [FromBody] CreateGeoFenceRequest request, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _geoFenceService.UpdateFenceAsync(id, userId, request, cancellationToken);
        return ApiResponse<GeoFenceResponse>.Ok(result, SuccessMessages.GeoFence.UpdateSuccess);
    }

    /// <summary>
    /// 删除电子围栏
    /// </summary>
    [HttpDelete("{id}")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [EnableRateLimiting("WritePolicy")]
    public async Task<ApiResponse<object>> DeleteFence(Guid id, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _geoFenceService.DeleteFenceAsync(id, userId, cancellationToken);
        return ApiResponse<object>.Ok(null!, SuccessMessages.GeoFence.DeleteSuccess);
    }
}
