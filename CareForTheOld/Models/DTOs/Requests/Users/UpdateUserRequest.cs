using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Users;

public class UpdateUserRequest
{
    [StringLength(50, ErrorMessage = "姓名长度不能超过50")]
    public string? RealName { get; set; }

    [StringLength(500, ErrorMessage = "头像地址长度不能超过500")]
    public string? AvatarUrl { get; set; }
}