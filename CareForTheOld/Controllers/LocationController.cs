using CareForTheOld.Models.DTOs.Requests.Location;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

/// <summary>
/// 位置控制器
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class LocationController : ControllerBase
{
    private readonly ILocationService _locationService;
    private readonly IFamilyService _familyService;

    public LocationController(ILocationService locationService, IFamilyService familyService)
    {
        _locationService = locationService;
        _familyService = familyService;
    }

    private Guid? GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim))
            return null;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    /// <summary>
    /// 上报位置（老人端）
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<LocationRecordResponse>> ReportLocation([FromBody] ReportLocationRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        try
        {
            var record = await _locationService.ReportLocationAsync(userId.Value, request.Latitude, request.Longitude);
            return Ok(new { success = true, data = record });
        }
        catch (Exception ex)
        {
            return BadRequest(new { success = false, message = ex.Message });
        }
    }

    /// <summary>
    /// 获取我的最新位置
    /// </summary>
    [HttpGet("me/latest")]
    public async Task<ActionResult<LocationRecordResponse>> GetMyLatestLocation()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var record = await _locationService.GetLatestLocationAsync(userId.Value);
        if (record == null)
            return Ok(new { success = true, message = "暂无位置记录" });

        return Ok(new { success = true, data = record });
    }

    /// <summary>
    /// 获取我的位置历史
    /// </summary>
    [HttpGet("me/history")]
    public async Task<ActionResult<List<LocationRecordResponse>>> GetMyHistory([FromQuery] int limit = 50)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var records = await _locationService.GetLocationHistoryAsync(userId.Value, limit);
        return Ok(new { success = true, data = records });
    }

    /// <summary>
    /// 获取家庭成员最新位置（子女查看老人）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/latest")]
    public async Task<ActionResult<LocationRecordResponse>> GetFamilyMemberLatestLocation(Guid familyId, Guid memberId)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        // 验证当前用户是否是该家庭成员
        var members = await _familyService.GetMembersAsync(familyId);
        if (!members.Any(m => m.UserId == userId.Value))
            return Forbid("您不是该家庭成员");

        var record = await _locationService.GetFamilyMemberLatestLocationAsync(familyId, memberId);
        if (record == null)
            return Ok(new { success = true, message = "该老人暂无位置记录" });

        return Ok(new { success = true, data = record });
    }

    /// <summary>
    /// 获取家庭成员位置历史（子女查看老人）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/history")]
    public async Task<ActionResult<List<LocationRecordResponse>>> GetFamilyMemberHistory(Guid familyId, Guid memberId, [FromQuery] int limit = 50)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        // 验证当前用户是否是该家庭成员
        var members = await _familyService.GetMembersAsync(familyId);
        if (!members.Any(m => m.UserId == userId.Value))
            return Forbid("您不是该家庭成员");

        var records = await _locationService.GetFamilyMemberLocationHistoryAsync(familyId, memberId, limit);
        return Ok(new { success = true, data = records });
    }
}