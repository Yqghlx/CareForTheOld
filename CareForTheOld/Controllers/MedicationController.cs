using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Medication;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

/// <summary>
/// 用药提醒控制器
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class MedicationController : ControllerBase
{
    private readonly IMedicationService _medicationService;

    public MedicationController(IMedicationService medicationService)
    {
        _medicationService = medicationService;
    }

    /// <summary>
    /// 创建用药计划（子女为老人创建）
    /// </summary>
    [HttpPost("plans")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<MedicationPlanResponse>> CreatePlan([FromBody] CreateMedicationPlanRequest request)
    {
        var userId = this.GetUserId();
        var result = await _medicationService.CreatePlanAsync(userId, request);
        return ApiResponse<MedicationPlanResponse>.Ok(result, SuccessMessages.Medication.CreateSuccess);
    }

    /// <summary>
    /// 获取老人的用药计划列表（需为家庭成员）
    /// </summary>
    [HttpGet("plans/elder/{elderId:guid}")]
    [CacheControl(MaxAgeSeconds = 60)]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<List<MedicationPlanResponse>>> GetPlansByElder(Guid elderId)
    {
        var userId = this.GetUserId();
        var result = await _medicationService.GetPlansByElderAsync(elderId, userId);
        return ApiResponse<List<MedicationPlanResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取自己的用药计划（老人查看）
    /// </summary>
    [HttpGet("plans/me")]
    [CacheControl(MaxAgeSeconds = 60)]
    [Authorize(Roles = "Elder")]
    public async Task<ApiResponse<List<MedicationPlanResponse>>> GetMyPlans()
    {
        var userId = this.GetUserId();
        var result = await _medicationService.GetPlansByElderAsync(userId);
        return ApiResponse<List<MedicationPlanResponse>>.Ok(result);
    }

    /// <summary>
    /// 更新用药计划
    /// </summary>
    [HttpPut("plans/{id:guid}")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<MedicationPlanResponse>> UpdatePlan(Guid id, [FromBody] UpdateMedicationPlanRequest request)
    {
        var userId = this.GetUserId();
        var result = await _medicationService.UpdatePlanAsync(id, userId, request);
        return ApiResponse<MedicationPlanResponse>.Ok(result, SuccessMessages.Medication.UpdateSuccess);
    }

    /// <summary>
    /// 删除用药计划
    /// </summary>
    [HttpDelete("plans/{id:guid}")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<object>> DeletePlan(Guid id)
    {
        var userId = this.GetUserId();
        await _medicationService.DeletePlanAsync(id, userId);
        return ApiResponse<object>.Ok(null!, SuccessMessages.Medication.DeleteSuccess);
    }

    /// <summary>
    /// 记录用药日志（已服/跳过）
    /// </summary>
    [HttpPost("logs")]
    [Authorize(Roles = "Elder")]
    public async Task<ApiResponse<MedicationLogResponse>> RecordLog([FromBody] RecordMedicationLogRequest request)
    {
        var userId = this.GetUserId();
        var result = await _medicationService.RecordLogAsync(userId, request);
        return ApiResponse<MedicationLogResponse>.Ok(result, SuccessMessages.Medication.LogSuccess);
    }

    /// <summary>
    /// 获取用药日志列表（子女查看老人，需为家庭成员）
    /// </summary>
    [HttpGet("logs/elder/{elderId:guid}")]
    [CacheControl(MaxAgeSeconds = 60)]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<List<MedicationLogResponse>>> GetLogs(
        Guid elderId,
        [FromQuery] DateOnly? date,
        [FromQuery] int skip = 0,
        [FromQuery] int limit = 50)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();
        var result = await _medicationService.GetLogsAsync(elderId, date, skip, limit, userId);
        return ApiResponse<List<MedicationLogResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取自己的用药日志（老人查看）
    /// </summary>
    [HttpGet("logs/me")]
    [CacheControl(MaxAgeSeconds = 60)]
    [Authorize(Roles = "Elder")]
    public async Task<ApiResponse<List<MedicationLogResponse>>> GetMyLogs(
        [FromQuery] DateOnly? date,
        [FromQuery] int skip = 0,
        [FromQuery] int limit = 50)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();
        var result = await _medicationService.GetLogsAsync(userId, date, skip, limit);
        return ApiResponse<List<MedicationLogResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取今日待服药列表
    /// </summary>
    [HttpGet("today-pending")]
    [CacheControl(MaxAgeSeconds = 30)]
    [Authorize(Roles = "Elder")]
    public async Task<ApiResponse<List<MedicationLogResponse>>> GetTodayPending()
    {
        var userId = this.GetUserId();
        var result = await _medicationService.GetTodayPendingAsync(userId);
        return ApiResponse<List<MedicationLogResponse>>.Ok(result);
    }
}
