using System.Security.Claims;

namespace CareForTheOld.Common.Middleware;

/// <summary>
/// 审计日志中间件
/// 记录所有写操作（POST/PUT/PATCH/DELETE），用于安全审计和问题追溯
/// 读取操作（GET）不记录，避免性能影响
/// </summary>
public class AuditLogMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<AuditLogMiddleware> _logger;

    public AuditLogMiddleware(RequestDelegate next, ILogger<AuditLogMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // 仅记录写操作
        var method = context.Request.Method;
        if (method is "GET" or "HEAD" or "OPTIONS" or "TRACE")
        {
            await _next(context);
            return;
        }

        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        var path = context.Request.Path;
        var timestamp = DateTime.UtcNow;

        // 先执行请求，再记录结果
        await _next(context);

        var statusCode = context.Response.StatusCode;
        var logLevel = statusCode >= 400 ? LogLevel.Warning : LogLevel.Information;

        _logger.Log(logLevel,
            "审计日志 | 时间: {Timestamp:O} | 方法: {Method} | 路径: {Path} | 用户: {UserId} | 状态码: {StatusCode}",
            timestamp, method, path, userId ?? "匿名", statusCode);
    }
}
