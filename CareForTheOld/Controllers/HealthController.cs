using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Health;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

/// <summary>
/// 健康记录控制器
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class HealthController : ControllerBase
{
    private readonly IHealthService _healthService;
    private readonly IFamilyService _familyService;
    private readonly IHealthReportService _reportService;

    public HealthController(
        IHealthService healthService,
        IFamilyService familyService,
        IHealthReportService reportService)
    {
        _healthService = healthService;
        _familyService = familyService;
        _reportService = reportService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// 创建健康记录（老人录入数据）
    /// </summary>
    [HttpPost]
    public async Task<ApiResponse<HealthRecordResponse>> CreateRecord([FromBody] CreateHealthRecordRequest request)
    {
        var result = await _healthService.CreateRecordAsync(CurrentUserId, request);
        return ApiResponse<HealthRecordResponse>.Ok(result, "记录成功");
    }

    /// <summary>
    /// 获取自己的健康记录列表
    /// </summary>
    [HttpGet("me")]
    public async Task<ApiResponse<List<HealthRecordResponse>>> GetMyRecords(
        [FromQuery] HealthType? type,
        [FromQuery] int limit = 50)
    {
        var result = await _healthService.GetUserRecordsAsync(CurrentUserId, type, limit);
        return ApiResponse<List<HealthRecordResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取家庭成员的健康记录（子女查看老人数据）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}")]
    public async Task<ApiResponse<List<HealthRecordResponse>>> GetFamilyMemberRecords(
        Guid familyId,
        Guid memberId,
        [FromQuery] HealthType? type,
        [FromQuery] int limit = 50)
    {
        // 验证当前用户是否是该家庭成员
        var members = await _familyService.GetMembersAsync(familyId);
        if (!members.Any(m => m.UserId == CurrentUserId))
            return ApiResponse<List<HealthRecordResponse>>.Fail("您不是该家庭成员");

        var result = await _healthService.GetFamilyMemberRecordsAsync(familyId, memberId, type, limit);
        return ApiResponse<List<HealthRecordResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取健康数据统计
    /// </summary>
    [HttpGet("me/stats")]
    public async Task<ApiResponse<List<HealthStatsResponse>>> GetMyStats()
    {
        var result = await _healthService.GetUserStatsAsync(CurrentUserId);
        return ApiResponse<List<HealthStatsResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取家庭成员的健康数据统计
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/stats")]
    public async Task<ApiResponse<List<HealthStatsResponse>>> GetFamilyMemberStats(
        Guid familyId,
        Guid memberId)
    {
        // 验证当前用户是否是该家庭成员
        var members = await _familyService.GetMembersAsync(familyId);
        if (!members.Any(m => m.UserId == CurrentUserId))
            return ApiResponse<List<HealthStatsResponse>>.Fail("您不是该家庭成员");

        var result = await _healthService.GetUserStatsAsync(memberId);
        return ApiResponse<List<HealthStatsResponse>>.Ok(result);
    }

    /// <summary>
    /// 删除健康记录
    /// </summary>
    [HttpDelete("{id:guid}")]
    public async Task<ApiResponse<object>> DeleteRecord(Guid id)
    {
        await _healthService.DeleteRecordAsync(CurrentUserId, id);
        return ApiResponse<object>.Ok(null!, "删除成功");
    }

    /// <summary>
    /// 导出自己的健康报告 PDF
    /// </summary>
    [HttpGet("me/report")]
    public async Task<IActionResult> ExportMyReport([FromQuery] int days = 7)
    {
        var pdfBytes = await _reportService.GeneratePdfReportAsync(CurrentUserId, days);
        var fileName = $"健康报告_{DateTime.Now:yyyyMMdd}.pdf";
        return File(pdfBytes, "application/pdf", fileName);
    }

    /// <summary>
    /// 导出家庭成员的健康报告 PDF（子女导出老人报告）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/report")]
    public async Task<IActionResult> ExportFamilyMemberReport(
        Guid familyId,
        Guid memberId,
        [FromQuery] int days = 7)
    {
        // 验证当前用户是否是该家庭成员
        var members = await _familyService.GetMembersAsync(familyId);
        if (!members.Any(m => m.UserId == CurrentUserId))
            return Forbid();

        var pdfBytes = await _reportService.GeneratePdfReportAsync(memberId, days);
        var fileName = $"健康报告_{DateTime.Now:yyyyMMdd}.pdf";
        return File(pdfBytes, "application/pdf", fileName);
    }
}