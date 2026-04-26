namespace CareForTheOld.Common.Extensions;

/// <summary>
/// HttpContext 扩展方法
/// </summary>
public static class HttpContextExtensions
{
    /// <summary>
    /// 获取客户端真实 IP 地址
    ///
    /// 优先从 X-Forwarded-For / X-Real-IP 获取（兼容 Nginx 等反向代理），
    /// 回退到 Connection.RemoteIpAddress。
    /// </summary>
    public static string GetClientIp(this HttpContext context)
    {
        var forwardedFor = context.Request.Headers["X-Forwarded-For"].FirstOrDefault();
        if (!string.IsNullOrEmpty(forwardedFor))
        {
            // X-Forwarded-For 可能包含多个 IP，取第一个（最原始的客户端 IP）
            var ip = forwardedFor.Split(',').First().Trim();
            if (!string.IsNullOrEmpty(ip)) return ip;
        }
        var realIp = context.Request.Headers["X-Real-IP"].FirstOrDefault();
        if (!string.IsNullOrEmpty(realIp)) return realIp;
        return context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
    }
}
