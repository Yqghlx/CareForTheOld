namespace CareForTheOld.Common.Middleware;

/// <summary>
/// 请求追踪 ID 中间件
/// 为每个 HTTP 请求生成或透传唯一标识，便于日志关联和分布式追踪
/// </summary>
public class CorrelationIdMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<CorrelationIdMiddleware> _logger;

    /// <summary>请求头名称（同时用于请求和响应）</summary>
    private const string HeaderName = "X-Request-Id";

    public CorrelationIdMiddleware(RequestDelegate next, ILogger<CorrelationIdMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // 优先使用客户端传入的请求 ID（支持分布式链路追踪），否则生成新的
        var correlationId = context.Request.Headers.TryGetValue(HeaderName, out var value)
            ? value.ToString()
            : Guid.NewGuid().ToString("N")[..16]; // 短格式，日志更紧凑

        // 存入 HttpContext.Items，供其他中间件和日志使用
        context.Items[nameof(CorrelationIdMiddleware)] = correlationId;

        // 写入响应头，客户端可据此排查问题
        context.Response.Headers.TryAdd(HeaderName, correlationId);

        // 注入日志上下文，所有后续 ILogger 输出自动包含 RequestId
        using (_logger.BeginScope(new Dictionary<string, object> { ["RequestId"] = correlationId }))
        {
            await _next(context);
        }
    }
}
