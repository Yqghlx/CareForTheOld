using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Location;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Controllers;

/// <summary>
/// 位置控制器
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class LocationController : ControllerBase
{
    private readonly ILocationService _locationService;
    private readonly IFamilyService _familyService;

    public LocationController(ILocationService locationService, IFamilyService familyService)
    {
        _locationService = locationService;
        _familyService = familyService;
    }

    /// <summary>
    /// 上报位置（老人端）
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "Elder")]
    [ProducesResponseType(typeof(ApiResponse<LocationRecordResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    public async Task<ApiResponse<LocationRecordResponse>> ReportLocation([FromBody] ReportLocationRequest request, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var record = await _locationService.ReportLocationAsync(userId, request.Latitude, request.Longitude, request.Accuracy, cancellationToken);
        return ApiResponse<LocationRecordResponse>.Ok(record, SuccessMessages.Location.ReportSuccess);
    }

    /// <summary>
    /// 获取我的最新位置
    /// </summary>
    [HttpGet("me/latest")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheShortSeconds)]
    [ProducesResponseType(typeof(ApiResponse<LocationRecordResponse?>), StatusCodes.Status200OK)]
    public async Task<ApiResponse<LocationRecordResponse?>> GetMyLatestLocation(CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var record = await _locationService.GetLatestLocationAsync(userId, cancellationToken);
        return ApiResponse<LocationRecordResponse?>.Ok(record);
    }

    /// <summary>
    /// 获取我的位置历史
    /// </summary>
    [HttpGet("me/history")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    [ProducesResponseType(typeof(ApiResponse<List<LocationRecordResponse>>), StatusCodes.Status200OK)]
    public async Task<ApiResponse<List<LocationRecordResponse>>> GetMyHistory([FromQuery][Range(0, int.MaxValue)] int skip = AppConstants.Pagination.DefaultSkip, [FromQuery][Range(1, int.MaxValue)] int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();
        var records = await _locationService.GetLocationHistoryAsync(userId, skip, limit, cancellationToken);
        return ApiResponse<List<LocationRecordResponse>>.Ok(records);
    }

    /// <summary>
    /// 获取家庭成员最新位置（子女查看老人）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/latest")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheShortSeconds)]
    [Authorize(Roles = "Child")]
    [ProducesResponseType(typeof(ApiResponse<LocationRecordResponse?>), StatusCodes.Status200OK)]
    public async Task<ApiResponse<LocationRecordResponse?>> GetFamilyMemberLatestLocation(Guid familyId, Guid memberId, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();

        if (!await this.IsFamilyMemberAsync(_familyService, familyId, userId))
            return ApiResponse<LocationRecordResponse?>.Fail(ErrorMessages.Family.NotFamilyMember);
        if (!await this.IsFamilyMemberAsync(_familyService, familyId, memberId))
            return ApiResponse<LocationRecordResponse?>.Fail(ErrorMessages.Family.MemberNotInFamily);

        var record = await _locationService.GetFamilyMemberLatestLocationAsync(familyId, memberId, cancellationToken);
        return ApiResponse<LocationRecordResponse?>.Ok(record);
    }

    /// <summary>
    /// 获取家庭成员位置历史（子女查看老人）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/history")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    [Authorize(Roles = "Child")]
    [ProducesResponseType(typeof(ApiResponse<List<LocationRecordResponse>>), StatusCodes.Status200OK)]
    public async Task<ApiResponse<List<LocationRecordResponse>>> GetFamilyMemberHistory(
        Guid familyId, Guid memberId, [FromQuery][Range(0, int.MaxValue)] int skip = AppConstants.Pagination.DefaultSkip, [FromQuery][Range(1, int.MaxValue)] int limit = AppConstants.Pagination.DefaultPageSize, CancellationToken cancellationToken = default)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();

        if (!await this.IsFamilyMemberAsync(_familyService, familyId, userId))
            return ApiResponse<List<LocationRecordResponse>>.Fail(ErrorMessages.Family.NotFamilyMember);
        if (!await this.IsFamilyMemberAsync(_familyService, familyId, memberId))
            return ApiResponse<List<LocationRecordResponse>>.Fail(ErrorMessages.Family.MemberNotInFamily);

        var records = await _locationService.GetFamilyMemberLocationHistoryAsync(familyId, memberId, skip, limit, cancellationToken);
        return ApiResponse<List<LocationRecordResponse>>.Ok(records);
    }
}
