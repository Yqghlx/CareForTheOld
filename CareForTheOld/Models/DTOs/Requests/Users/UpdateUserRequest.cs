using CareForTheOld.Common.Constants;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Users;

public class UpdateUserRequest
{
    [StringLength(50, ErrorMessage = ValidationMessages.User.NameTooLong)]
    public string? RealName { get; set; }

    [Url(ErrorMessage = "头像地址格式不正确")]
    [StringLength(500, ErrorMessage = ValidationMessages.User.AvatarTooLong)]
    public string? AvatarUrl { get; set; }
}