using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Families;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FamilyController : ControllerBase
{
    private readonly IFamilyService _familyService;

    public FamilyController(IFamilyService familyService) => _familyService = familyService;

    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// 获取当前用户所属的家庭信息
    /// </summary>
    [HttpGet("me")]
    public async Task<ApiResponse<FamilyResponse?>> GetMyFamily()
    {
        var result = await _familyService.GetMyFamilyAsync(CurrentUserId);
        return ApiResponse<FamilyResponse?>.Ok(result);
    }

    [HttpPost]
    public async Task<ApiResponse<FamilyResponse>> Create([FromBody] CreateFamilyRequest request)
    {
        var result = await _familyService.CreateFamilyAsync(CurrentUserId, request);
        return ApiResponse<FamilyResponse>.Ok(result, "创建成功");
    }

    [HttpPost("{id:guid}/members")]
    public async Task<ApiResponse<FamilyResponse>> AddMember(Guid id, [FromBody] AddFamilyMemberRequest request)
    {
        var result = await _familyService.AddMemberAsync(id, CurrentUserId, request);
        return ApiResponse<FamilyResponse>.Ok(result, "邀请成功");
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
        await _familyService.RemoveMemberAsync(id, userId, CurrentUserId);
        return ApiResponse<object>.Ok(null!, "移除成功");
    }
}