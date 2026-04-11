using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Medication;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

/// <summary>
/// 用药提醒控制器
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MedicationController : ControllerBase
{
    private readonly IMedicationService _medicationService;

    public MedicationController(IMedicationService medicationService)
    {
        _medicationService = medicationService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// 创建用药计划（子女为老人创建）
    /// </summary>
    [HttpPost("plans")]
    public async Task<ApiResponse<MedicationPlanResponse>> CreatePlan([FromBody] CreateMedicationPlanRequest request)
    {
        var result = await _medicationService.CreatePlanAsync(CurrentUserId, request);
        return ApiResponse<MedicationPlanResponse>.Ok(result, "创建成功");
    }

    /// <summary>
    /// 获取老人的用药计划列表
    /// </summary>
    [HttpGet("plans/elder/{elderId:guid}")]
    public async Task<ApiResponse<List<MedicationPlanResponse>>> GetPlansByElder(Guid elderId)
    {
        var result = await _medicationService.GetPlansByElderAsync(elderId);
        return ApiResponse<List<MedicationPlanResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取自己的用药计划（老人查看）
    /// </summary>
    [HttpGet("plans/me")]
    public async Task<ApiResponse<List<MedicationPlanResponse>>> GetMyPlans()
    {
        var result = await _medicationService.GetPlansByElderAsync(CurrentUserId);
        return ApiResponse<List<MedicationPlanResponse>>.Ok(result);
    }

    /// <summary>
    /// 更新用药计划
    /// </summary>
    [HttpPut("plans/{id:guid}")]
    public async Task<ApiResponse<MedicationPlanResponse>> UpdatePlan(Guid id, [FromBody] UpdateMedicationPlanRequest request)
    {
        var result = await _medicationService.UpdatePlanAsync(id, CurrentUserId, request);
        return ApiResponse<MedicationPlanResponse>.Ok(result, "更新成功");
    }

    /// <summary>
    /// 删除用药计划
    /// </summary>
    [HttpDelete("plans/{id:guid}")]
    public async Task<ApiResponse<object>> DeletePlan(Guid id)
    {
        await _medicationService.DeletePlanAsync(id, CurrentUserId);
        return ApiResponse<object>.Ok(null!, "删除成功");
    }

    /// <summary>
    /// 记录用药日志（已服/跳过）
    /// </summary>
    [HttpPost("logs")]
    public async Task<ApiResponse<MedicationLogResponse>> RecordLog([FromBody] RecordMedicationLogRequest request)
    {
        var result = await _medicationService.RecordLogAsync(CurrentUserId, request);
        return ApiResponse<MedicationLogResponse>.Ok(result, "记录成功");
    }

    /// <summary>
    /// 获取用药日志列表
    /// </summary>
    [HttpGet("logs/elder/{elderId:guid}")]
    public async Task<ApiResponse<List<MedicationLogResponse>>> GetLogs(
        Guid elderId,
        [FromQuery] DateOnly? date,
        [FromQuery] int limit = 50)
    {
        var result = await _medicationService.GetLogsAsync(elderId, date, limit);
        return ApiResponse<List<MedicationLogResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取自己的用药日志（老人查看）
    /// </summary>
    [HttpGet("logs/me")]
    public async Task<ApiResponse<List<MedicationLogResponse>>> GetMyLogs(
        [FromQuery] DateOnly? date,
        [FromQuery] int limit = 50)
    {
        var result = await _medicationService.GetLogsAsync(CurrentUserId, date, limit);
        return ApiResponse<List<MedicationLogResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取今日待服药列表
    /// </summary>
    [HttpGet("today-pending")]
    public async Task<ApiResponse<List<MedicationLogResponse>>> GetTodayPending()
    {
        var result = await _medicationService.GetTodayPendingAsync(CurrentUserId);
        return ApiResponse<List<MedicationLogResponse>>.Ok(result);
    }
}