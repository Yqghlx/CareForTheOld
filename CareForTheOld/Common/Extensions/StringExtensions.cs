namespace CareForTheOld.Common.Extensions;

/// <summary>
/// 字符串扩展方法
/// </summary>
public static class StringExtensions
{
    /// <summary>
    /// 手机号脱敏处理：保留前 3 位和后 4 位，中间用 **** 替代
    /// 例如：13800138000 → 138****8000
    /// </summary>
    public static string MaskPhoneNumber(this string phone)
    {
        if (string.IsNullOrEmpty(phone) || phone.Length < 7)
            return phone;

        return string.Concat(phone.AsSpan(0, 3), "****", phone.AsSpan(phone.Length - 4));
    }
}
