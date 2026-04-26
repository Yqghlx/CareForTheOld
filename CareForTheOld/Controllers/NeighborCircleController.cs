using Asp.Versioning;
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
    [CacheControl(MaxAgeSeconds = 60)]
    public async Task<ApiResponse<NeighborCircleResponse?>> GetMyCircle()
    {
        var userId = this.GetUserId();
        var result = await _circleService.GetMyCircleAsync(userId);
        return ApiResponse<NeighborCircleResponse?>.Ok(result);
    }

    /// <summary>
    /// 创建邻里圈
    /// </summary>
    [HttpPost]
    public async Task<ApiResponse<NeighborCircleResponse>> Create([FromBody] CreateNeighborCircleRequest request)
    {
        var userId = this.GetUserId();
        var result = await _circleService.CreateCircleAsync(userId, request);
        return ApiResponse<NeighborCircleResponse>.Ok(result, "创建成功");
    }

    /// <summary>
    /// 获取邻里圈详情（仅成员可查看）
    /// </summary>
    [HttpGet("{id:guid}")]
    [CacheControl(MaxAgeSeconds = 60)]
    public async Task<ApiResponse<NeighborCircleResponse>> GetCircle(Guid id)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(id, userId);

        var result = await _circleService.GetCircleAsync(id);
        return ApiResponse<NeighborCircleResponse>.Ok(result);
    }

    /// <summary>
    /// 获取邻里圈成员列表（仅成员可查看）
    /// </summary>
    [HttpGet("{id:guid}/members")]
    [CacheControl(MaxAgeSeconds = 60)]
    public async Task<ApiResponse<List<NeighborMemberResponse>>> GetMembers(Guid id)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(id, userId);

        var result = await _circleService.GetMembersAsync(id);
        return ApiResponse<List<NeighborMemberResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取附近成员（基于最近位置记录）
    /// </summary>
    [HttpGet("{id:guid}/nearby-members")]
    [CacheControl(MaxAgeSeconds = 60)]
    public async Task<ApiResponse<List<NeighborMemberResponse>>> GetNearbyMembers(
        Guid id, [FromQuery] double latitude, [FromQuery] double longitude, [FromQuery] double radius = 500)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(id, userId);

        var result = await _circleService.GetNearbyMembersAsync(id, latitude, longitude, radius);
        return ApiResponse<List<NeighborMemberResponse>>.Ok(result);
    }

    /// <summary>
    /// 通过邀请码加入邻里圈（严格限流，防止暴力破解）
    /// </summary>
    [HttpPost("join")]
    [EnableRateLimiting("JoinCirclePolicy")]
    public async Task<ApiResponse<NeighborCircleResponse>> Join([FromBody] JoinNeighborCircleRequest request)
    {
        var userId = this.GetUserId();
        var result = await _circleService.JoinCircleByCodeAsync(userId, request);
        return ApiResponse<NeighborCircleResponse>.Ok(result, "加入成功");
    }

    /// <summary>
    /// 退出邻里圈（创建者退出则解散）
    /// </summary>
    [HttpPost("{id:guid}/leave")]
    public async Task<ApiResponse<object>> Leave(Guid id)
    {
        var userId = this.GetUserId();
        await _circleService.LeaveCircleAsync(id, userId);
        return ApiResponse<object>.Ok(null!, "已退出邻里圈");
    }

    /// <summary>
    /// 刷新邀请码（仅圈主可操作）
    /// </summary>
    [HttpPost("{id:guid}/refresh-code")]
    public async Task<ApiResponse<NeighborCircleResponse>> RefreshInviteCode(Guid id)
    {
        var userId = this.GetUserId();
        var result = await _circleService.RefreshInviteCodeAsync(id, userId);
        return ApiResponse<NeighborCircleResponse>.Ok(result, "邀请码已刷新");
    }

    /// <summary>
    /// 搜索附近的邻里圈
    /// </summary>
    [HttpGet("nearby")]
    [CacheControl(MaxAgeSeconds = 60)]
    public async Task<ApiResponse<List<NeighborCircleResponse>>> SearchNearby(
        [FromQuery] double latitude, [FromQuery] double longitude, [FromQuery] double radius = 2000)
    {
        var result = await _circleService.SearchNearbyCirclesAsync(latitude, longitude, radius);
        return ApiResponse<List<NeighborCircleResponse>>.Ok(result);
    }
}
