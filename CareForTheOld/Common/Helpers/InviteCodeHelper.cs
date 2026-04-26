using System.Security.Cryptography;

namespace CareForTheOld.Common.Helpers;

/// <summary>
/// 邀请码生成工具
/// 使用加密随机数生成器，防止邀请码可预测攻击
/// </summary>
public static class InviteCodeHelper
{
    /// <summary>邀请码最小值（6位数字）</summary>
    private const int MinValue = 100000;

    /// <summary>邀请码最大值（6位数字）</summary>
    private const int MaxValue = 999999;

    /// <summary>
    /// 生成 6 位数字邀请码
    /// </summary>
    public static string Generate() => RandomNumberGenerator.GetInt32(MinValue, MaxValue).ToString();
}
