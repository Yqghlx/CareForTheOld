using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Emergency;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

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
    public async Task<ApiResponse<EmergencyCallResponse>> CreateCall([FromBody] CreateEmergencyCallRequest? request)
    {
        var userId = this.GetUserId();
        var call = await _emergencyService.CreateCallAsync(
            userId,
            request?.Latitude,
            request?.Longitude,
            request?.BatteryLevel);
        return ApiResponse<EmergencyCallResponse>.Ok(call, SuccessMessages.Emergency.CallSent);
    }

    /// <summary>
    /// 获取未处理的紧急呼叫（子女端）
    /// </summary>
    [HttpGet("unread")]
    [CacheControl(MaxAgeSeconds = 30)]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<List<EmergencyCallResponse>>> GetUnreadCalls()
    {
        var userId = this.GetUserId();
        var calls = await _emergencyService.GetUnreadCallsAsync(userId);
        return ApiResponse<List<EmergencyCallResponse>>.Ok(calls);
    }

    /// <summary>
    /// 获取历史呼叫记录
    /// </summary>
    [HttpGet("history")]
    [CacheControl(MaxAgeSeconds = 60)]
    public async Task<ApiResponse<List<EmergencyCallResponse>>> GetHistory([FromQuery] int skip = 0, [FromQuery] int limit = 20)
    {
        limit = Math.Clamp(limit, AppConstants.Pagination.MinPageSize, AppConstants.Pagination.MaxPageSize);
        var userId = this.GetUserId();
        var calls = await _emergencyService.GetHistoryAsync(userId, skip, limit);
        return ApiResponse<List<EmergencyCallResponse>>.Ok(calls);
    }

    /// <summary>
    /// 子女标记已处理
    /// </summary>
    [HttpPut("{id}/respond")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<EmergencyCallResponse>> RespondCall(Guid id)
    {
        var userId = this.GetUserId();
        var call = await _emergencyService.RespondCallAsync(id, userId);
        return ApiResponse<EmergencyCallResponse>.Ok(call, SuccessMessages.Emergency.MarkHandled);
    }
}
