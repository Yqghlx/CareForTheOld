using CareForTheOld.Common.Constants;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Users;

public class UpdateUserRequest
{
    [StringLength(50, ErrorMessage = ValidationMessages.User.NameTooLong)]
    public string? RealName { get; set; }

    [StringLength(500, ErrorMessage = ValidationMessages.User.AvatarTooLong)]
    public string? AvatarUrl { get; set; }
}