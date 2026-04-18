using System.Text.Json;
using CareForTheOld.Common.Helpers;

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
            _logger.LogError(ex, "未处理的异常: {Message}，路径: {Path}",
                ex.Message, context.Request.Path);
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";

        // 生产环境隐藏 ArgumentException 详细信息
        var (statusCode, message) = exception switch
        {
            KeyNotFoundException => (StatusCodes.Status404NotFound, "资源未找到"),
            UnauthorizedAccessException => (StatusCodes.Status401Unauthorized, "未授权"),
            ArgumentException => (StatusCodes.Status400BadRequest,
                _environment.IsDevelopment() ? exception.Message : "请求参数错误"),
            _ => (StatusCodes.Status500InternalServerError, "服务器内部错误")
        };

        context.Response.StatusCode = statusCode;

        var response = ApiResponse<object>.Fail(message);
        var json = JsonSerializer.Serialize(response, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        await context.Response.WriteAsync(json);
    }
}
