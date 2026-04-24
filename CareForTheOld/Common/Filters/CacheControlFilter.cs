using Microsoft.AspNetCore.Mvc.Filters;

namespace CareForTheOld.Common.Filters;

/// <summary>
/// 为 GET 请求响应添加 Cache-Control 头
/// 默认 private, max-age=60（客户端缓存 60 秒，不经过共享缓存）
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class CacheControlAttribute : ActionFilterAttribute
{
    /// <summary>
    /// 缓存时间（秒），默认 60 秒
    /// </summary>
    public int MaxAgeSeconds { get; set; } = 60;

    public override void OnResultExecuting(ResultExecutingContext context)
    {
        context.HttpContext.Response.Headers.CacheControl = $"private, max-age={MaxAgeSeconds}";
        base.OnResultExecuting(context);
    }
}
