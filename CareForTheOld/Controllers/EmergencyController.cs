using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

/// <summary>
/// 紧急呼叫控制器
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class EmergencyController : ControllerBase
{
    private readonly IEmergencyService _emergencyService;

    public EmergencyController(IEmergencyService emergencyService)
    {
        _emergencyService = emergencyService;
    }

    /// <summary>
    /// 老人发起紧急呼叫
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<EmergencyCallResponse>> CreateCall()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        try
        {
            var call = await _emergencyService.CreateCallAsync(userId.Value);
            return Ok(new { success = true, data = call });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { success = false, message = ex.Message });
        }
    }

    /// <summary>
    /// 获取未处理的紧急呼叫（子女端）
    /// </summary>
    [HttpGet("unread")]
    public async Task<ActionResult<List<EmergencyCallResponse>>> GetUnreadCalls()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var calls = await _emergencyService.GetUnreadCallsAsync(userId.Value);
        return Ok(new { success = true, data = calls });
    }

    /// <summary>
    /// 获取历史呼叫记录
    /// </summary>
    [HttpGet("history")]
    public async Task<ActionResult<List<EmergencyCallResponse>>> GetHistory([FromQuery] int limit = 20)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var calls = await _emergencyService.GetHistoryAsync(userId.Value, limit);
        return Ok(new { success = true, data = calls });
    }

    /// <summary>
    /// 子女标记已处理
    /// </summary>
    [HttpPut("{id}/respond")]
    public async Task<ActionResult<EmergencyCallResponse>> RespondCall(Guid id)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        try
        {
            var call = await _emergencyService.RespondCallAsync(id, userId.Value);
            return Ok(new { success = true, data = call });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { success = false, message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { success = false, message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
    }

    private Guid? GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim))
            return null;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }
}