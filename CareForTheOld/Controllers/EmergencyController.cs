using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Emergency;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Controllers;

/// <summary>
/// 紧急呼叫控制器
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class EmergencyController : ControllerBase
{
    private readonly IEmergencyService _emergencyService;

    public EmergencyController(IEmergencyService emergencyService)
    {
        _emergencyService = emergencyService;
    }

    /// <summary>
    /// 老人发起紧急呼叫（限流：每分钟最多3次）
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "Elder")]
    [EnableRateLimiting("EmergencyPolicy")]
    [ProducesResponseType(typeof(ApiResponse<EmergencyCallResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ApiResponse<EmergencyCallResponse>> CreateCall([FromBody] CreateEmergencyCallRequest? request, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var call = await _emergencyService.CreateCallAsync(
            userId,
            request?.Latitude,
            request?.Longitude,
            request?.BatteryLevel,
            cancellationToken);
        return ApiResponse<EmergencyCallResponse>.Ok(call, SuccessMessages.Emergency.CallSent);
    }

    /// <summary>
    /// 获取未处理的紧急呼叫（子女端）
    /// </summary>
    [HttpGet("unread")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheShortSeconds)]
    [Authorize(Roles = "Child")]
    [ProducesResponseType(typeof(ApiResponse<List<EmergencyCallResponse>>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ApiResponse<List<EmergencyCallResponse>>> GetUnreadCalls(CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var calls = await _emergencyService.GetUnreadCallsAsync(userId, cancellationToken);
        return ApiResponse<List<EmergencyCallResponse>>.Ok(calls);
    }

    /// <summary>
    /// 获取历史呼叫记录
    /// </summary>
    [HttpGet("history")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    [ProducesResponseType(typeof(ApiResponse<List<EmergencyCallResponse>>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ApiResponse<List<EmergencyCallResponse>>> GetHistory([FromQuery][Range(0, int.MaxValue)] int skip = AppConstants.Pagination.DefaultSkip, [FromQuery][Range(1, int.MaxValue)] int limit = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();
        var calls = await _emergencyService.GetHistoryAsync(userId, skip, limit, cancellationToken);
        return ApiResponse<List<EmergencyCallResponse>>.Ok(calls);
    }

    /// <summary>
    /// 子女标记已处理
    /// </summary>
    [HttpPut("{id}/respond")]
    [Authorize(Roles = "Child")]
    [ProducesResponseType(typeof(ApiResponse<EmergencyCallResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [EnableRateLimiting("WritePolicy")]
    public async Task<ApiResponse<EmergencyCallResponse>> RespondCall(Guid id, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        var call = await _emergencyService.RespondCallAsync(id, userId, cancellationToken);
        return ApiResponse<EmergencyCallResponse>.Ok(call, SuccessMessages.Emergency.MarkHandled);
    }
}
