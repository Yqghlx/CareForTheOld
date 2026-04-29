using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Controllers;

/// <summary>
/// 自动救援控制器
/// 提供救援记录查询、子女响应确认等功能
/// 围栏越界或心跳超时后自动触发救援流程
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/auto-rescue")]
[Authorize(Roles = "Child")]
[EnableRateLimiting("GeneralPolicy")]
public class AutoRescueController : ControllerBase
{
    private readonly IAutoRescueService _autoRescueService;
    private readonly IFamilyService _familyService;

    public AutoRescueController(
        IAutoRescueService autoRescueService,
        IFamilyService familyService)
    {
        _autoRescueService = autoRescueService;
        _familyService = familyService;
    }

    /// <summary>
    /// 子女主动响应自动救援告警
    /// </summary>
    [HttpPost("{recordId:guid}/respond")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [EnableRateLimiting("WritePolicy")]
    public async Task<ApiResponse<object>> ChildRespond(Guid recordId, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _autoRescueService.ChildRespondAsync(recordId, userId, cancellationToken);
        return ApiResponse<object>.Ok(null!, SuccessMessages.AutoRescue.RespondConfirmed);
    }

    /// <summary>
    /// 获取自动救援历史记录
    /// </summary>
    [HttpGet("history")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    public async Task<ApiResponse<object>> GetHistory([FromQuery][Range(0, int.MaxValue)] int skip = AppConstants.Pagination.DefaultSkip, [FromQuery][Range(1, int.MaxValue)] int limit = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();

        var family = await _familyService.GetMyFamilyAsync(userId, cancellationToken);
        if (family == null)
            return ApiResponse<object>.Fail(ErrorMessages.Family.NotJoinedFamily);

        var records = await _autoRescueService.GetHistoryAsync(family.Id, skip, limit, cancellationToken);
        var result = records.Select(r => new
        {
            r.Id,
            r.ElderId,
            ElderName = r.Elder?.RealName ?? string.Empty,
            TriggerType = r.TriggerType.GetLabel(),
            Status = r.Status.GetLabel(),
            r.TriggeredAt,
            r.ChildNotifiedAt,
            r.ChildRespondedAt,
            r.BroadcastAt,
            r.ResolvedAt,
        });
        return ApiResponse<object>.Ok(result);
    }
}
