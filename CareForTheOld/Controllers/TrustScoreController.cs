using Asp.Versioning;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

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
    public async Task<ApiResponse<object>> GetRanking(Guid circleId, [FromQuery] int top = 20)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(circleId, userId);

        var rankings = await _trustScoreService.GetCircleRankingAsync(circleId, top);
        var result = rankings.Select((r, index) => new
        {
            Rank = index + 1,
            r.UserId,
            UserName = r.User.RealName,
            r.TotalHelps,
            AvgRating = Math.Round(r.AvgRating, 1),
            ResponseRate = Math.Round(r.ResponseRate * 100, 1),
            Score = Math.Round(r.Score, 1),
        });
        return ApiResponse<object>.Ok(result);
    }

    /// <summary>
    /// 获取我的信任评分
    /// </summary>
    [HttpGet("me")]
    public async Task<ApiResponse<object>> GetMyScore(Guid circleId)
    {
        var userId = this.GetUserId();
        await _circleService.EnsureCircleMemberAsync(circleId, userId);

        var score = await _trustScoreService.GetUserScoreAsync(userId, circleId);
        return ApiResponse<object>.Ok(new { Score = Math.Round(score, 1) });
    }
}
