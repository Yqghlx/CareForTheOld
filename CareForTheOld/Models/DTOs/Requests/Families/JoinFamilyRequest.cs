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
    [Required(ErrorMessage = "邀请码不能为空")]
    [StringLength(6, MinimumLength = 6, ErrorMessage = "邀请码为6位")]
    public string InviteCode { get; set; } = string.Empty;

    /// <summary>
    /// 与创建者的关系（如：女儿、儿子）
    /// </summary>
    [Required(ErrorMessage = "关系不能为空")]
    [StringLength(20, ErrorMessage = "关系描述长度不能超过20")]
    public string Relation { get; set; } = string.Empty;
}