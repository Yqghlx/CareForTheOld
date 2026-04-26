using Asp.Versioning;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Filters;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Health;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using CareForTheOld.Services.Implementations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

/// <summary>
/// 健康记录控制器
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class HealthController : ControllerBase
{
    private readonly IHealthService _healthService;
    private readonly IHealthQueryService _healthQueryService;
    private readonly IFamilyService _familyService;
    private readonly IHealthReportService _reportService;
    private readonly HealthAnomalyDetector _anomalyDetector;

    public HealthController(
        IHealthService healthService,
        IHealthQueryService healthQueryService,
        IFamilyService familyService,
        IHealthReportService reportService,
        HealthAnomalyDetector anomalyDetector)
    {
        _healthService = healthService;
        _healthQueryService = healthQueryService;
        _familyService = familyService;
        _reportService = reportService;
        _anomalyDetector = anomalyDetector;
    }

    /// <summary>
    /// 创建健康记录（老人录入数据）
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "Elder")]
    public async Task<ApiResponse<HealthRecordResponse>> CreateRecord([FromBody] CreateHealthRecordRequest request)
    {
        var userId = this.GetUserId();
        var result = await _healthService.CreateRecordAsync(userId, request);
        return ApiResponse<HealthRecordResponse>.Ok(result, SuccessMessages.Health.RecordSuccess);
    }

    /// <summary>
    /// 获取自己的健康记录列表
    /// </summary>
    [HttpGet("me")]
    [CacheControl(MaxAgeSeconds = 60)]
    public async Task<ApiResponse<List<HealthRecordResponse>>> GetMyRecords(
        [FromQuery] HealthType? type,
        [FromQuery] int skip = AppConstants.Pagination.DefaultSkip,
        [FromQuery] int limit = AppConstants.Pagination.DefaultPageSize)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();
        var result = await _healthService.GetUserRecordsAsync(userId, type, skip, limit);
        return ApiResponse<List<HealthRecordResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取家庭成员的健康记录（子女查看老人数据）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}")]
    [CacheControl(MaxAgeSeconds = 60)]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<List<HealthRecordResponse>>> GetFamilyMemberRecords(
        Guid familyId,
        Guid memberId,
        [FromQuery] HealthType? type,
        [FromQuery] int skip = AppConstants.Pagination.DefaultSkip,
        [FromQuery] int limit = AppConstants.Pagination.DefaultPageSize)
    {
        limit = this.ClampLimit(limit);
        var userId = this.GetUserId();

        if (!await IsFamilyMemberAsync(familyId))
            return ApiResponse<List<HealthRecordResponse>>.Fail(ErrorMessages.Family.NotFamilyMember);

        var result = await _healthService.GetFamilyMemberRecordsAsync(familyId, memberId, type, skip, limit);
        return ApiResponse<List<HealthRecordResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取健康数据统计
    /// </summary>
    [HttpGet("me/stats")]
    [CacheControl(MaxAgeSeconds = 300)]
    public async Task<ApiResponse<List<HealthStatsResponse>>> GetMyStats()
    {
        var userId = this.GetUserId();
        var result = await _healthQueryService.GetUserStatsAsync(userId);
        return ApiResponse<List<HealthStatsResponse>>.Ok(result);
    }

    /// <summary>
    /// 获取家庭成员的健康数据统计
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/stats")]
    [CacheControl(MaxAgeSeconds = 300)]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<List<HealthStatsResponse>>> GetFamilyMemberStats(
        Guid familyId,
        Guid memberId)
    {
        var userId = this.GetUserId();

        if (!await IsFamilyMemberAsync(familyId))
            return ApiResponse<List<HealthStatsResponse>>.Fail(ErrorMessages.Family.NotFamilyMember);

        var result = await _healthQueryService.GetUserStatsAsync(memberId);
        return ApiResponse<List<HealthStatsResponse>>.Ok(result);
    }

    /// <summary>
    /// 删除健康记录
    /// </summary>
    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "Elder")]
    public async Task<ApiResponse<object>> DeleteRecord(Guid id)
    {
        var userId = this.GetUserId();
        await _healthService.DeleteRecordAsync(userId, id);
        return ApiResponse<object>.Ok(null!, SuccessMessages.Health.DeleteSuccess);
    }

    /// <summary>
    /// 导出自己的健康报告 PDF
    /// </summary>
    [HttpGet("me/report")]
    [Authorize(Roles = "Elder")]
    public async Task<IActionResult> ExportMyReport([FromQuery] int days = 7)
    {
        var userId = this.GetUserId();
        var pdfBytes = await _reportService.GeneratePdfReportAsync(userId, days);
        return File(pdfBytes, AppConstants.MimeTypes.Pdf, GenerateReportFileName());
    }

    /// <summary>
    /// 导出家庭成员的健康报告 PDF（子女导出老人报告）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/report")]
    [Authorize(Roles = "Child")]
    public async Task<IActionResult> ExportFamilyMemberReport(
        Guid familyId,
        Guid memberId,
        [FromQuery] int days = 7)
    {
        var userId = this.GetUserId();

        if (!await IsFamilyMemberAsync(familyId))
            return Forbid();

        var pdfBytes = await _reportService.GeneratePdfReportAsync(memberId, days);
        return File(pdfBytes, AppConstants.MimeTypes.Pdf, GenerateReportFileName());
    }

    /// <summary>
    /// 获取自己的健康趋势异常检测（老人查看）
    /// </summary>
    [HttpGet("me/anomaly-detection")]
    [CacheControl(MaxAgeSeconds = 300)]
    public async Task<ApiResponse<TrendAnomalyDetectionResponse>> GetMyAnomalyDetection(
        [FromQuery] HealthType? type)
    {
        var userId = this.GetUserId();

        // 如果未指定类型，默认返回血压异常检测（最常见的关注点）
        var healthType = type ?? HealthType.BloodPressure;

        // 获取最近60天的健康记录用于异常检测
        var records = await _healthService.GetUserRecordsAsync(userId, healthType, 0, AppConstants.AnomalyEvaluation.MaxQueryRecords);

        if (records.Count < AppConstants.AnomalyEvaluation.MinimumRecords)
        {
            return ApiResponse<TrendAnomalyDetectionResponse>.Ok(
                new TrendAnomalyDetectionResponse
                {
                    Type = healthType,
                    TypeName = healthType.ToString(),
                },
                SuccessMessages.Health.InsufficientRecordsForAnomaly);
        }

        // 转换为检测器需要的格式
        var healthRecords = records
            .Select(r => (RecordedAt: r.RecordedAt, Value: GetValueForType(r, healthType)))
            .Where(r => r.Value > 0)
            .ToList();

        var result = _anomalyDetector.DetectAnomalies(healthRecords, healthType);
        return ApiResponse<TrendAnomalyDetectionResponse>.Ok(result);
    }

    /// <summary>
    /// 获取家庭成员的健康趋势异常检测（子女查看老人）
    /// </summary>
    [HttpGet("family/{familyId:guid}/member/{memberId:guid}/anomaly-detection")]
    [CacheControl(MaxAgeSeconds = 300)]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<TrendAnomalyDetectionResponse>> GetFamilyMemberAnomalyDetection(
        Guid familyId,
        Guid memberId,
        [FromQuery] HealthType? type)
    {
        var userId = this.GetUserId();

        if (!await IsFamilyMemberAsync(familyId))
            return ApiResponse<TrendAnomalyDetectionResponse>.Fail(ErrorMessages.Family.NotFamilyMember);

        var healthType = type ?? HealthType.BloodPressure;
        var records = await _healthService.GetFamilyMemberRecordsAsync(familyId, memberId, healthType, 0, AppConstants.AnomalyEvaluation.MaxQueryRecords);

        if (records.Count < AppConstants.AnomalyEvaluation.MinimumRecords)
        {
            return ApiResponse<TrendAnomalyDetectionResponse>.Ok(
                new TrendAnomalyDetectionResponse
                {
                    Type = healthType,
                    TypeName = healthType.ToString(),
                },
                SuccessMessages.Health.InsufficientRecordsForAnomaly);
        }

        var healthRecords = records
            .Select(r => (RecordedAt: r.RecordedAt, Value: GetValueForType(r, healthType)))
            .Where(r => r.Value > 0)
            .ToList();

        var result = _anomalyDetector.DetectAnomalies(healthRecords, healthType);
        return ApiResponse<TrendAnomalyDetectionResponse>.Ok(result);
    }

    /// <summary>
    /// 验证当前用户是否是指定家庭的成员
    /// </summary>
    private async Task<bool> IsFamilyMemberAsync(Guid familyId)
    {
        var userId = this.GetUserId();
        var members = await _familyService.GetMembersAsync(familyId);
        return members.Any(m => m.UserId == userId);
    }

    /// <summary>
    /// 生成健康报告文件名
    /// </summary>
    private static string GenerateReportFileName()
        => $"{HealthReportMessages.FileName.Prefix}_{DateTime.UtcNow.ToString(HealthReportMessages.FileName.DateFormat)}{HealthReportMessages.FileName.Extension}";

    /// <summary>
    /// 根据健康类型提取对应的数值（转换为 double）
    /// </summary>
    private static double GetValueForType(HealthRecordResponse record, HealthType type)
    {
        return type switch
        {
            HealthType.BloodPressure => record.Systolic ?? 0,
            HealthType.BloodSugar => (double)(record.BloodSugar ?? 0),
            HealthType.HeartRate => record.HeartRate ?? 0,
            HealthType.Temperature => (double)(record.Temperature ?? 0),
            _ => 0,
        };
    }
}
