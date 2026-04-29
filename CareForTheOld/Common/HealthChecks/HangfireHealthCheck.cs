using Hangfire;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace CareForTheOld.Common.HealthChecks;

/// <summary>
/// Hangfire 后台任务健康检查
/// 监控 Hangfire 服务器状态和失败任务数量
/// </summary>
public class HangfireHealthCheck : IHealthCheck
{
    private readonly JobStorage _jobStorage;
    private readonly ILogger<HangfireHealthCheck> _logger;

    public HangfireHealthCheck(JobStorage jobStorage, ILogger<HangfireHealthCheck> logger)
    {
        _jobStorage = jobStorage;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            var monitor = _jobStorage.GetMonitoringApi();

            // 检查服务器是否在线（最近 5 分钟有心跳）
            var servers = await Task.Run(() => monitor.Servers(), cancellationToken);
            var activeServers = servers.Count(s => s.Heartbeat.HasValue && s.Heartbeat > DateTime.UtcNow.AddMinutes(-5));

            if (activeServers == 0)
            {
                return HealthCheckResult.Degraded("Hangfire: 无活跃服务器");
            }

            // 检查失败任务数量
            var failedCount = await Task.Run(() => monitor.FailedCount(), cancellationToken);

            var data = new Dictionary<string, object>
            {
                ["ActiveServers"] = activeServers,
                ["TotalServers"] = servers.Count,
                ["FailedJobs"] = failedCount,
            };

            if (failedCount > 100)
            {
                return HealthCheckResult.Unhealthy($"Hangfire: 失败任务过多 ({failedCount})", data: data);
            }

            if (failedCount > 10)
            {
                return HealthCheckResult.Degraded($"Hangfire: 存在失败任务 ({failedCount})", data: data);
            }

            return HealthCheckResult.Healthy($"Hangfire: {activeServers} 个服务器在线", data);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Hangfire 健康检查异常");
            return HealthCheckResult.Unhealthy("Hangfire: 无法连接", exception: ex);
        }
    }
}
