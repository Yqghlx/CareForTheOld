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
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Controllers;

/// <summary>
/// 邻里互助控制器
/// 提求求助发布、响应、完成和评分等功能
/// 支持基于地理位置的邻居互助服务，与邻里圈联动
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/neighborhelp")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class NeighborHelpController : ControllerBase
{
    private readonly INeighborHelpService _helpService;

    public NeighborHelpController(INeighborHelpService helpService) => _helpService = helpService;

    /// <summary>
    /// 获取待响应的求助列表
    /// </summary>
    [HttpGet("pending")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheShortSeconds)]
    public async Task<ApiResponse<List<NeighborHelpRequestResponse>>> GetPending(CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _helpService.GetPendingRequestsAsync(userId, cancellationToken);
        return ApiResponse<List<NeighborHelpRequestResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取互助历史记录
    /// </summary>
    [HttpGet("history")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    public async Task<ApiResponse<List<NeighborHelpRequestResponse>>> GetHistory(
        [FromQuery][Range(0, int.MaxValue)] int skip = AppConstants.Pagination.DefaultSkip, [FromQuery][Range(1, int.MaxValue)] int limit = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();
        var result = await _helpService.GetHistoryAsync(userId, skip, limit, cancellationToken);
        return ApiResponse<List<NeighborHelpRequestResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取求助请求详情
    /// </summary>
    [HttpGet("{id:guid}")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    public async Task<ApiResponse<NeighborHelpRequestResponse>> GetRequest(Guid id, CancellationToken cancellationToken = default)
    {
        var result = await _helpService.GetRequestAsync(id, cancellationToken);
        return ApiResponse<NeighborHelpRequestResponse>.Ok(result);
    }

    /// <summary>
    /// 接受求助请求（第一个接受者生效）
    /// </summary>
    [HttpPut("{id:guid}/accept")]
    public async Task<ApiResponse<NeighborHelpRequestResponse>> Accept(Guid id, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _helpService.AcceptHelpRequestAsync(id, userId, cancellationToken);
        return ApiResponse<NeighborHelpRequestResponse>.Ok(result, SuccessMessages.NeighborHelp.AcceptSuccess);
    }

    /// <summary>
    /// 取消求助请求（仅求助者或其子女）
    /// </summary>
    [HttpPut("{id:guid}/cancel")]
    public async Task<ApiResponse<object>> Cancel(Guid id, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _helpService.CancelHelpRequestAsync(id, userId, cancellationToken);
        return ApiResponse<object>.Ok(null!, SuccessMessages.NeighborHelp.CancelSuccess);
    }

    /// <summary>
    /// 评价互助（1-5 星）
    /// </summary>
    [HttpPost("{id:guid}/rate")]
    public async Task<ApiResponse<NeighborHelpRatingResponse>> Rate(
        Guid id, [FromBody] RateHelpRequest request, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var result = await _helpService.RateHelpRequestAsync(id, userId, request, cancellationToken);
        return ApiResponse<NeighborHelpRatingResponse>.Ok(result, SuccessMessages.NeighborHelp.RateSuccess);
    }
}
