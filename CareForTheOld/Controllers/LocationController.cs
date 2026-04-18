using Asp.Versioning;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Location;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

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
    public async Task<ApiResponse<LocationRecordResponse>> ReportLocation([FromBody] ReportLocationRequest request)
    {
        var userId = this.GetUserId();
        var record = await _locationService.ReportLocationAsync(userId, request.Latitude, request.Longitude);
        return ApiResponse<LocationRecordResponse>.Ok(record, "位置上报成功");
    }

    /// <summary>
    /// 获取我的最新位置
    /// </summary>
    [HttpGet("me/latest")]
    public async Task<ApiResponse<LocationRecordResponse?>> GetMyLatestLocation()
    {
        var userId = this.GetUserId();
        var record = await _locationService.GetLatestLocationAsync(userId);
        return ApiResponse<LocationRecordResponse?>.Ok(record);
    }

    /// <summary>
    /// 获取我的位置历史
    /// </summary>
    [HttpGet("me/history")]
    public async Task<ApiResponse<List<LocationRecordResponse>>> GetMyHistory([FromQuery] int skip = 0, [FromQuery] int limit = 50)
    {
        var userId = this.GetUserId();
        var records = await _locationService.GetLocationHistoryAsync(userId, skip, limit);
        return ApiResponse<List<LocationRecordResponse>>.Ok(records);
    }

    /// <summary>
    /// 获取家庭成员最新位置（子女查看老人）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/latest")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<LocationRecordResponse?>> GetFamilyMemberLatestLocation(Guid familyId, Guid memberId)
    {
        var userId = this.GetUserId();

        // 验证当前用户是否是该家庭成员
        var members = await _familyService.GetMembersAsync(familyId);
        if (!members.Any(m => m.UserId == userId))
            return ApiResponse<LocationRecordResponse?>.Fail("您不是该家庭成员");

        var record = await _locationService.GetFamilyMemberLatestLocationAsync(familyId, memberId);
        return ApiResponse<LocationRecordResponse?>.Ok(record);
    }

    /// <summary>
    /// 获取家庭成员位置历史（子女查看老人）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/history")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<List<LocationRecordResponse>>> GetFamilyMemberHistory(
        Guid familyId, Guid memberId, [FromQuery] int skip = 0, [FromQuery] int limit = 50)
    {
        var userId = this.GetUserId();

        // 验证当前用户是否是该家庭成员
        var members = await _familyService.GetMembersAsync(familyId);
        if (!members.Any(m => m.UserId == userId))
            return ApiResponse<List<LocationRecordResponse>>.Fail("您不是该家庭成员");

        var records = await _locationService.GetFamilyMemberLocationHistoryAsync(familyId, memberId, skip, limit);
        return ApiResponse<List<LocationRecordResponse>>.Ok(records);
    }
}
