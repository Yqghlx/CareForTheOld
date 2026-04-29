using System.ComponentModel.DataAnnotations;
using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Neighbor;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

/// <summary>
/// 邻里圈管理控制器
/// 提供邻里圈创建、加入、退出、成员查询和附近圈子搜索等功能
/// 邻里圈用于社区互助，支持地理位置范围的成员管理
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class NeighborCircleController : ControllerBase
{
    private readonly INeighborCircleService _circleService;

    public NeighborCircleController(INeighborCircleService circleService) => _circleService = circleService;

    /// <summary>
    /// 获取当前用户加入的邻里圈
    /// </summary>
    [HttpGet("me")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    public async Task<ApiResponse<NeighborCircleResponse?>> GetMyCircle(CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _circleService.GetMyCircleAsync(userId, cancellationToken);
        return ApiResponse<NeighborCircleResponse?>.Ok(result);
    }

    /// <summary>
    /// 创建邻里圈
    /// </summary>
    [HttpPost]
    public async Task<ApiResponse<NeighborCircleResponse>> Create([FromBody] CreateNeighborCircleRequest request, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _circleService.CreateCircleAsync(userId, request, cancellationToken);
        return ApiResponse<NeighborCircleResponse>.Ok(result, SuccessMessages.NeighborCircle.CreateSuccess);
    }

    /// <summary>
    /// 获取邻里圈详情（仅成员可查看）
    /// </summary>
    [HttpGet("{id:guid}")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    public async Task<ApiResponse<NeighborCircleResponse>> GetCircle(Guid id, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(id, userId, cancellationToken);

        var result = await _circleService.GetCircleAsync(id, cancellationToken);
        return ApiResponse<NeighborCircleResponse>.Ok(result);
    }

    /// <summary>
    /// 获取邻里圈成员列表（仅成员可查看）
    /// </summary>
    [HttpGet("{id:guid}/members")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    public async Task<ApiResponse<List<NeighborMemberResponse>>> GetMembers(Guid id, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(id, userId, cancellationToken);

        var result = await _circleService.GetMembersAsync(id, cancellationToken);
        return ApiResponse<List<NeighborMemberResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取附近成员（基于最近位置记录）
    /// </summary>
    [HttpGet("{id:guid}/nearby-members")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    public async Task<ApiResponse<List<NeighborMemberResponse>>> GetNearbyMembers(
        Guid id, [FromQuery, Range(-90.0, 90.0)] double latitude, [FromQuery, Range(-180.0, 180.0)] double longitude, [FromQuery] double radius = AppConstants.NeighborCircle.DefaultMemberRadiusMeters, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(id, userId, cancellationToken);

        var result = await _circleService.GetNearbyMembersAsync(id, latitude, longitude, radius, cancellationToken);
        return ApiResponse<List<NeighborMemberResponse>>.Ok(result);
    }

    /// <summary>
    /// 通过邀请码加入邻里圈（严格限流，防止暴力破解）
    /// </summary>
    [HttpPost("join")]
    [EnableRateLimiting("JoinCirclePolicy")]
    public async Task<ApiResponse<NeighborCircleResponse>> Join([FromBody] JoinNeighborCircleRequest request, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _circleService.JoinCircleByCodeAsync(userId, request, cancellationToken);
        return ApiResponse<NeighborCircleResponse>.Ok(result, SuccessMessages.NeighborCircle.JoinSuccess);
    }

    /// <summary>
    /// 退出邻里圈（创建者退出则解散）
    /// </summary>
    [HttpPost("{id:guid}/leave")]
    public async Task<ApiResponse<object>> Leave(Guid id, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _circleService.LeaveCircleAsync(id, userId, cancellationToken);
        return ApiResponse<object>.Ok(null!, SuccessMessages.NeighborCircle.LeaveSuccess);
    }

    /// <summary>
    /// 刷新邀请码（仅圈主可操作）
    /// </summary>
    [HttpPost("{id:guid}/refresh-code")]
    public async Task<ApiResponse<NeighborCircleResponse>> RefreshInviteCode(Guid id, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _circleService.RefreshInviteCodeAsync(id, userId, cancellationToken);
        return ApiResponse<NeighborCircleResponse>.Ok(result, SuccessMessages.NeighborCircle.InviteCodeRefreshed);
    }

    /// <summary>
    /// 搜索附近的邻里圈
    /// </summary>
    [HttpGet("nearby")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    public async Task<ApiResponse<List<NeighborCircleResponse>>> SearchNearby(
        [FromQuery, Range(-90.0, 90.0)] double latitude, [FromQuery, Range(-180.0, 180.0)] double longitude, [FromQuery] double radius = AppConstants.NeighborCircle.SearchRadiusMeters, CancellationToken cancellationToken = default)
    {
        var result = await _circleService.SearchNearbyCirclesAsync(latitude, longitude, radius, cancellationToken: cancellationToken);
        return ApiResponse<List<NeighborCircleResponse>>.Ok(result);
    }
}
