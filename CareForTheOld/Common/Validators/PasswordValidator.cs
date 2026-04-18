using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace CareForTheOld.Common.Validators;

/// <summary>
/// 密码复杂度验证器
/// 要求：至少 8 位，包含数字和字母
/// </summary>
public class PasswordValidatorAttribute : ValidationAttribute
{
    public PasswordValidatorAttribute()
    {
        ErrorMessage = "密码长度至少8位，且必须包含数字和字母";
    }

    public override bool IsValid(object? value)
    {
        if (value is not string password || string.IsNullOrEmpty(password))
            return false;

        if (password.Length < 8)
            return false;

        // 必须包含至少一个字母
        if (!Regex.IsMatch(password, @"[a-zA-Z]"))
            return false;

        // 必须包含至少一个数字
        if (!Regex.IsMatch(password, @"\d"))
            return false;

        return true;
    }
}
