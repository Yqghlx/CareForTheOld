using Asp.Versioning;
using System.ComponentModel.DataAnnotations;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

/// <summary>
/// 信任评分控制器
/// 提供邻里圈信任排行榜和个人信任评分查询功能
/// 信任评分基于互助历史、响应率和评价综合计算
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/neighbor-circles/{circleId:guid}/trust")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class TrustScoreController : ControllerBase
{
    private readonly ITrustScoreService _trustScoreService;
    private readonly INeighborCircleService _circleService;

    public TrustScoreController(
        ITrustScoreService trustScoreService,
        INeighborCircleService circleService)
    {
        _trustScoreService = trustScoreService;
        _circleService = circleService;
    }

    /// <summary>
    /// 获取圈内信任排行榜
    /// </summary>
    [HttpGet("ranking")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    public async Task<ApiResponse<object>> GetRanking(Guid circleId, [FromQuery, Range(1, 100)] int top = AppConstants.Pagination.DefaultHistoryPageSize, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(circleId, userId, cancellationToken);

        var rankings = await _trustScoreService.GetCircleRankingAsync(circleId, top, cancellationToken);
        var result = rankings.Select((r, index) => new
        {
            Rank = index + 1,
            r.UserId,
            UserName = r.User?.RealName ?? string.Empty,
            r.TotalHelps,
            AvgRating = Math.Round(r.AvgRating, AppConstants.TrustScore.DisplayDecimalPlaces),
            ResponseRate = Math.Round(r.ResponseRate * 100, AppConstants.TrustScore.DisplayDecimalPlaces),
            Score = Math.Round(r.Score, AppConstants.TrustScore.DisplayDecimalPlaces),
        });
        return ApiResponse<object>.Ok(result);
    }

    /// <summary>
    /// 获取我的信任评分
    /// </summary>
    [HttpGet("me")]
    [CacheControl(MaxAgeSeconds = AppConstants.Cache.HttpCacheMediumSeconds)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    public async Task<ApiResponse<object>> GetMyScore(Guid circleId, CancellationToken cancellationToken = default)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(circleId, userId, cancellationToken);

        var score = await _trustScoreService.GetUserScoreAsync(userId, circleId, cancellationToken);
        return ApiResponse<object>.Ok(new { Score = Math.Round(score, AppConstants.TrustScore.DisplayDecimalPlaces) });
    }
}
