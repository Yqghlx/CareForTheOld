using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Families;

public class CreateFamilyRequest
{
    [Required(ErrorMessage = "家庭组名称不能为空")]
    [StringLength(100, ErrorMessage = "名称长度不能超过100")]
    public string FamilyName { get; set; } = string.Empty;
}