using Asp.Versioning;
using CareForTheOld.Common.Extensions;
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
    public async Task<ApiResponse<List<NeighborHelpRequestResponse>>> GetPending()
    {
        var userId = this.GetUserId();
        var result = await _helpService.GetPendingRequestsAsync(userId);
        return ApiResponse<List<NeighborHelpRequestResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取互助历史记录
    /// </summary>
    [HttpGet("history")]
    public async Task<ApiResponse<List<NeighborHelpRequestResponse>>> GetHistory(
        [FromQuery] int skip = 0, [FromQuery] int limit = 20)
    {
        var userId = this.GetUserId();
        var result = await _helpService.GetHistoryAsync(userId, skip, limit);
        return ApiResponse<List<NeighborHelpRequestResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取求助请求详情
    /// </summary>
    [HttpGet("{id:guid}")]
    public async Task<ApiResponse<NeighborHelpRequestResponse>> GetRequest(Guid id)
    {
        var result = await _helpService.GetRequestAsync(id);
        return ApiResponse<NeighborHelpRequestResponse>.Ok(result);
    }

    /// <summary>
    /// 接受求助请求（第一个接受者生效）
    /// </summary>
    [HttpPut("{id:guid}/accept")]
    public async Task<ApiResponse<NeighborHelpRequestResponse>> Accept(Guid id)
    {
        var userId = this.GetUserId();
        var result = await _helpService.AcceptHelpRequestAsync(id, userId);
        return ApiResponse<NeighborHelpRequestResponse>.Ok(result, "已接受求助");
    }

    /// <summary>
    /// 取消求助请求（仅求助者或其子女）
    /// </summary>
    [HttpPut("{id:guid}/cancel")]
    public async Task<ApiResponse<object>> Cancel(Guid id)
    {
        var userId = this.GetUserId();
        await _helpService.CancelHelpRequestAsync(id, userId);
        return ApiResponse<object>.Ok(null!, "已取消求助");
    }

    /// <summary>
    /// 评价互助（1-5 星）
    /// </summary>
    [HttpPost("{id:guid}/rate")]
    public async Task<ApiResponse<NeighborHelpRatingResponse>> Rate(
        Guid id, [FromBody] RateHelpRequest request)
    {
        var userId = this.GetUserId();
        var result = await _helpService.RateHelpRequestAsync(id, userId, request);
        return ApiResponse<NeighborHelpRatingResponse>.Ok(result, "评价成功");
    }
}
