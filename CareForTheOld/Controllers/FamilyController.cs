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

    /// <summary>
    /// 创建家庭组（仅子女可创建，老人通过邀请码加入）
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<FamilyResponse>> Create([FromBody] CreateFamilyRequest request)
    {
        var userId = this.GetUserId();
        var result = await _familyService.CreateFamilyAsync(userId, request);
        return ApiResponse<FamilyResponse>.Ok(result, "创建成功");
    }

    /// <summary>
    /// 添加家庭成员（仅子女可操作，通过手机号邀请已注册用户）
    /// </summary>
    [HttpPost("{id:guid}/members")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<FamilyResponse>> AddMember(Guid id, [FromBody] AddFamilyMemberRequest request)
    {
        var userId = this.GetUserId();
        var result = await _familyService.AddMemberAsync(id, userId, request);
        return ApiResponse<FamilyResponse>.Ok(result, "邀请成功");
    }

    /// <summary>
    /// 通过邀请码申请加入家庭（严格限流，防止暴力破解邀请码）
    /// </summary>
    [HttpPost("join")]
    [EnableRateLimiting("JoinFamilyPolicy")]
    public async Task<ApiResponse<JoinFamilyResponse>> JoinFamily([FromBody] JoinFamilyRequest request)
    {
        var userId = this.GetUserId();
        var result = await _familyService.JoinFamilyByCodeAsync(userId, request);
        return ApiResponse<JoinFamilyResponse>.Ok(result, "申请已提交");
    }

    /// <summary>
    /// 刷新邀请码（仅子女可操作）
    /// </summary>
    [HttpPost("{id:guid}/refresh-code")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<FamilyResponse>> RefreshInviteCode(Guid id)
    {
        var userId = this.GetUserId();
        var result = await _familyService.RefreshInviteCodeAsync(id, userId);
        return ApiResponse<FamilyResponse>.Ok(result, "邀请码已刷新");
    }

    /// <summary>
    /// 获取已通过审批的家庭成员列表
    /// </summary>
    [HttpGet("{id:guid}/members")]
    public async Task<ApiResponse<List<FamilyMemberResponse>>> GetMembers(Guid id)
    {
        // 验证请求者是该家庭成员，防止越权查看
        var userId = this.GetUserId();
        var members = await _familyService.GetMembersAsync(id);
        if (!members.Any(m => m.UserId == userId))
            return ApiResponse<List<FamilyMemberResponse>>.Fail("您不是该家庭成员");
        return ApiResponse<List<FamilyMemberResponse>>.Ok(members);
    }

    /// <summary>
    /// 获取待审批成员列表（仅子女可查看）
    /// </summary>
    [HttpGet("{id:guid}/pending-members")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<List<FamilyMemberResponse>>> GetPendingMembers(Guid id)
    {
        var userId = this.GetUserId();
        var result = await _familyService.GetPendingMembersAsync(id, userId);
        return ApiResponse<List<FamilyMemberResponse>>.Ok(result);
    }

    /// <summary>
    /// 审批通过成员加入（仅子女可操作）
    /// </summary>
    [HttpPost("{id:guid}/members/{memberId:guid}/approve")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<object>> ApproveMember(Guid id, Guid memberId)
    {
        var userId = this.GetUserId();
        await _familyService.ApproveMemberAsync(id, memberId, userId);
        return ApiResponse<object>.Ok(null!, "审批通过");
    }

    /// <summary>
    /// 拒绝成员加入申请（仅子女可操作）
    /// </summary>
    [HttpPost("{id:guid}/members/{memberId:guid}/reject")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<object>> RejectMember(Guid id, Guid memberId)
    {
        var userId = this.GetUserId();
        await _familyService.RejectMemberAsync(id, memberId, userId);
        return ApiResponse<object>.Ok(null!, "已拒绝");
    }

    [HttpDelete("{id:guid}/members/{userId:guid}")]
    [Authorize(Roles = "Child")]
    public async Task<ApiResponse<object>> RemoveMember(Guid id, Guid userId)
    {
        var currentUserId = this.GetUserId();
        await _familyService.RemoveMemberAsync(id, userId, currentUserId);
        return ApiResponse<object>.Ok(null!, "移除成功");
    }
}
