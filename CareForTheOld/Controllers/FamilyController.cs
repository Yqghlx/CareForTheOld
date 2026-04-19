using Asp.Versioning;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareForTheOld.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
[Authorize]
[EnableRateLimiting("GeneralPolicy")]
public class FamilyController : ControllerBase
{
    private readonly IFamilyService _familyService;

    public FamilyController(IFamilyService familyService) => _familyService = familyService;

    /// <summary>
    /// 获取当前用户所属的家庭信息
    /// </summary>
    [HttpGet("me")]
    public async Task<ApiResponse<FamilyResponse?>> GetMyFamily()
    {
        var userId = this.GetUserId();
        var result = await _familyService.GetMyFamilyAsync(userId);
        return ApiResponse<FamilyResponse?>.Ok(result);
    }

    [HttpPost]
    public async Task<ApiResponse<FamilyResponse>> Create([FromBody] CreateFamilyRequest request)
    {
        var userId = this.GetUserId();
        var result = await _familyService.CreateFamilyAsync(userId, request);
        return ApiResponse<FamilyResponse>.Ok(result, "创建成功");
    }

    [HttpPost("{id:guid}/members")]
    public async Task<ApiResponse<FamilyResponse>> AddMember(Guid id, [FromBody] AddFamilyMemberRequest request)
    {
        var userId = this.GetUserId();
        var result = await _familyService.AddMemberAsync(id, userId, request);
        return ApiResponse<FamilyResponse>.Ok(result, "邀请成功");
    }

    /// <summary>
    /// 通过邀请码加入家庭（严格限流，防止暴力破解邀请码）
    /// </summary>
    [HttpPost("join")]
    [EnableRateLimiting("JoinFamilyPolicy")]
    public async Task<ApiResponse<FamilyResponse>> JoinFamily([FromBody] JoinFamilyRequest request)
    {
        var userId = this.GetUserId();
        var result = await _familyService.JoinFamilyByCodeAsync(userId, request);
        return ApiResponse<FamilyResponse>.Ok(result, "加入成功");
    }

    /// <summary>
    /// 刷新邀请码
    /// </summary>
    [HttpPost("{id:guid}/refresh-code")]
    public async Task<ApiResponse<FamilyResponse>> RefreshInviteCode(Guid id)
    {
        var userId = this.GetUserId();
        var result = await _familyService.RefreshInviteCodeAsync(id, userId);
        return ApiResponse<FamilyResponse>.Ok(result, "邀请码已刷新");
    }

    [HttpGet("{id:guid}/members")]
    public async Task<ApiResponse<List<FamilyMemberResponse>>> GetMembers(Guid id)
    {
        var result = await _familyService.GetMembersAsync(id);
        return ApiResponse<List<FamilyMemberResponse>>.Ok(result);
    }

    [HttpDelete("{id:guid}/members/{userId:guid}")]
    public async Task<ApiResponse<object>> RemoveMember(Guid id, Guid userId)
    {
        var currentUserId = this.GetUserId();
        await _familyService.RemoveMemberAsync(id, userId, currentUserId);
        return ApiResponse<object>.Ok(null!, "移除成功");
    }
}
