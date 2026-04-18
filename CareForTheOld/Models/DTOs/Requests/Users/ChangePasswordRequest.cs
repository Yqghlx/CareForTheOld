using CareForTheOld.Common.Validators;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Users;

/// <summary>
/// 修改密码请求
/// </summary>
public class ChangePasswordRequest
{
    /// <summary>
    /// 旧密码
    /// </summary>
    [Required(ErrorMessage = "旧密码不能为空")]
    public string OldPassword { get; set; } = string.Empty;

    /// <summary>
    /// 新密码（与注册一致：至少 8 位，必须包含字母和数字）
    /// </summary>
    [Required(ErrorMessage = "新密码不能为空")]
    [PasswordValidator]
    public string NewPassword { get; set; } = string.Empty;
}