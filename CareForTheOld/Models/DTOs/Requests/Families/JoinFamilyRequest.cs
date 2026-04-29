using CareForTheOld.Common.Constants;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Families;

/// <summary>
/// 通过邀请码加入家庭请求
/// </summary>
public class JoinFamilyRequest
{
    /// <summary>
    /// 邀请码
    /// </summary>
    [Required(ErrorMessage = ValidationMessages.Family.InviteCodeRequired)]
    [StringLength(6, MinimumLength = 6, ErrorMessage = ValidationMessages.Family.InviteCodeInvalid)]
    [RegularExpression(@"^\d{6}$", ErrorMessage = ValidationMessages.Family.InviteCodeFormat)]
    public string InviteCode { get; set; } = string.Empty;

    /// <summary>
    /// 与创建者的关系（如：女儿、儿子）
    /// </summary>
    [Required(ErrorMessage = ValidationMessages.Family.RelationshipRequired)]
    [StringLength(20, ErrorMessage = ValidationMessages.Family.RelationshipTooLong)]
    public string Relation { get; set; } = string.Empty;
}