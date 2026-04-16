using CareForTheOld.Models.DTOs.Requests.GeoFences;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

/// <summary>
/// 电子围栏控制器
/// </summary>
[ApiController]
[Route("api/geofence")]
[Authorize]
public class GeoFenceController : ControllerBase
{
    private readonly IGeoFenceService _geoFenceService;

    public GeoFenceController(IGeoFenceService geoFenceService)
    {
        _geoFenceService = geoFenceService;
    }

    /// <summary>
    /// 创建电子围栏
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<GeoFenceResponse>> CreateFence([FromBody] CreateGeoFenceRequest request)
    {
        var userId = GetCurrentUserId();
        var result = await _geoFenceService.CreateFenceAsync(userId, request);
        return Ok(result);
    }

    /// <summary>
    /// 获取老人的电子围栏
    /// </summary>
    [HttpGet("elder/{elderId}")]
    public async Task<ActionResult<GeoFenceResponse?>> GetElderFence(Guid elderId)
    {
        var result = await _geoFenceService.GetElderFenceAsync(elderId);
        return Ok(result);
    }

    /// <summary>
    /// 更新电子围栏
    /// </summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<GeoFenceResponse>> UpdateFence(Guid id, [FromBody] CreateGeoFenceRequest request)
    {
        var userId = GetCurrentUserId();
        var result = await _geoFenceService.UpdateFenceAsync(id, userId, request);
        return Ok(result);
    }

    /// <summary>
    /// 删除电子围栏
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteFence(Guid id)
    {
        var userId = GetCurrentUserId();
        await _geoFenceService.DeleteFenceAsync(id, userId);
        return Ok(new { success = true });
    }

    /// <summary>
    /// 获取当前用户ID
    /// </summary>
    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId)
            ? userId
            : throw new UnauthorizedAccessException("无法获取用户ID");
    }
}