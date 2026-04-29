using System.Text.Json;
using CareForTheOld.Common.Constants;
using CareForTheOld.Common.Helpers;
using CareForTheOld.Common.Middleware;

namespace CareForTheOld.Common.Middleware;

/// <summary>
/// 全局异常处理中间件
/// 生产环境隐藏详细异常信息，仅记录日志
/// </summary>
public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;
    private readonly IHostEnvironment _environment;

    public ExceptionHandlingMiddleware(
        RequestDelegate next,
        ILogger<ExceptionHandlingMiddleware> logger,
        IHostEnvironment environment)
    {
        _next = next;
        _logger = logger;
        _environment = environment;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "未处理的异常 | 请求: {RequestId} | 路径: {Path}",
                context.Items[nameof(CorrelationIdMiddleware)], context.Request.Path);
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = AppConstants.MimeTypes.Json;

        var isDev = _environment.IsDevelopment();

        // 开发环境返回详细错误信息，生产环境隐藏内部细节
        var (statusCode, message) = exception switch
        {
            KeyNotFoundException => (StatusCodes.Status404NotFound, ErrorMessages.Middleware.NotFound),
            UnauthorizedAccessException => (StatusCodes.Status401Unauthorized, ErrorMessages.Middleware.Unauthorized),
            ArgumentException => (StatusCodes.Status400BadRequest,
                isDev ? exception.Message : ErrorMessages.Middleware.BadRequest),
            // 临时性故障：超时、取消、网络问题 → 503 Service Unavailable（前端可重试）
            TimeoutException or OperationCanceledException or TaskCanceledException
                => (StatusCodes.Status503ServiceUnavailable, ErrorMessages.Middleware.ServiceUnavailable),
            System.Net.Sockets.SocketException or IOException
                => (StatusCodes.Status503ServiceUnavailable, ErrorMessages.Middleware.ServiceUnavailable),
            _ => (StatusCodes.Status500InternalServerError,
                isDev ? exception.Message : ErrorMessages.Middleware.InternalError)
        };

        context.Response.StatusCode = statusCode;

        var response = ApiResponse<object>.Fail(message);
        response.RequestId = context.Items[nameof(CorrelationIdMiddleware)]?.ToString();
        var json = JsonSerializer.Serialize(response, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        await context.Response.WriteAsync(json);
    }
}
