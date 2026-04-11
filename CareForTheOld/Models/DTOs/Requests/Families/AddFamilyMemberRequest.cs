using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Families;

public class AddFamilyMemberRequest
{
    [Required(ErrorMessage = "手机号不能为空")]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = "角色不能为空")]
    public UserRole Role { get; set; }

    [Required(ErrorMessage = "关系不能为空")]
    [StringLength(20, ErrorMessage = "关系描述长度不能超过20")]
    public string Relation { get; set; } = string.Empty;
}