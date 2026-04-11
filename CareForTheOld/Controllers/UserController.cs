using CareForTheOld.Common.Helpers;
using CareForTheOld.Models.DTOs.Requests.Users;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CareForTheOld.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UserController : ControllerBase
{
    private readonly IUserService _userService;

    public UserController(IUserService userService) => _userService = userService;

    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet("me")]
    public async Task<ApiResponse<UserResponse>> GetCurrentUser()
    {
        var result = await _userService.GetCurrentUserAsync(CurrentUserId);
        return ApiResponse<UserResponse>.Ok(result);
    }

    [HttpPut("me")]
    public async Task<ApiResponse<UserResponse>> UpdateUser([FromBody] UpdateUserRequest request)
    {
        var result = await _userService.UpdateUserAsync(CurrentUserId, request);
        return ApiResponse<UserResponse>.Ok(result, "更新成功");
    }

    [HttpGet("{id:guid}")]
    public async Task<ApiResponse<UserResponse>> GetUserById(Guid id)
    {
        var result = await _userService.GetUserByIdAsync(id);
        return ApiResponse<UserResponse>.Ok(result);
    }
}