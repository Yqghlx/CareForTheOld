namespace CareForTheOld.Common.Middleware;

/// <summary>
/// 安全响应头中间件
/// 为每个响应添加标准安全头，防止常见的 Web 攻击
/// </summary>
public class SecurityHeadersMiddleware
{
    private readonly RequestDelegate _next;

    public SecurityHeadersMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // 防止 MIME 类型嗅探，浏览器必须遵守声明的 Content-Type
        context.Response.Headers.XContentTypeOptions = "nosniff";

        // 防止页面被嵌入 iframe，防御点击劫持（Clickjacking）
        context.Response.Headers.XFrameOptions = "DENY";

        // 启用浏览器内置 XSS 过滤器
        context.Response.Headers["X-XSS-Protection"] = "1; mode=block";

        // 控制 Referer 头的发送范围，保护用户隐私
        context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";

        // 内容安全策略：限制资源加载来源
        // 开发环境允许 localhost 连接 SignalR 和 Swagger，生产环境仅允许 'self'
        var csp = context.Request.Host.Host is "localhost" or "127.0.0.1"
            ? "default-src 'self'; connect-src 'self' http://localhost:* https://localhost:* ws://localhost:* wss://localhost:*; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
            : "default-src 'self'; connect-src 'self' wss:; script-src 'self'; style-src 'self'";

        context.Response.Headers["Content-Security-Policy"] = csp;

        // 移除可能泄露服务器技术栈的响应头
        context.Response.Headers.Remove("Server");
        context.Response.Headers.Remove("X-Powered-By");

        await _next(context);
    }
}
