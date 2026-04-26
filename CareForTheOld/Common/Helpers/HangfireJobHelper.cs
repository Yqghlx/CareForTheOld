using System.Linq.Expressions;
using Hangfire;

namespace CareForTheOld.Common.Helpers;

/// <summary>
/// Hangfire 后台任务辅助工具
/// 统一处理 Hangfire 入队异常，防止单个任务入队失败影响主流程
/// </summary>
public static class HangfireJobHelper
{
    /// <summary>
    /// 安全地将任务加入 Hangfire 队列，入队失败时仅记录日志不抛异常
    /// </summary>
    /// <param name="jobAction">任务委托</param>
    /// <param name="jobName">任务名称（用于日志标识）</param>
    /// <param name="logger">日志记录器</param>
    /// <param name="contextInfo">附加上下文信息（如实体 ID），用于日志追踪</param>
    public static void EnqueueSafely(Expression<Func<Task>> jobAction, string jobName, ILogger logger, object? contextInfo = null)
    {
        try
        {
            BackgroundJob.Enqueue(jobAction);
        }
        catch (Exception ex)
        {
            var message = contextInfo != null
                ? "{JobName}入队失败，上下文：{ContextInfo}"
                : "{JobName}入队失败";
            logger.LogError(ex, message, jobName, contextInfo);
        }
    }
}
