using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 健康数据只读查询接口（CQRS 查询端）
///
/// 使用 Dapper 原生 SQL 实现高频只读查询，绕过 EF Core 的变更追踪开销。
/// 写操作仍由 HealthService（EF Core）处理，保持强类型保障。
///
/// CQRS 读写分离的核心思路：
/// - Command（写）：HealthService + EF Core，利用变更追踪和关系映射
/// - Query（读）：IHealthQueryService + Dapper，利用原生 SQL 的性能优势
/// </summary>
public interface IHealthQueryService
{
    /// <summary>
    /// 获取用户健康趋势数据（7 天和 30 天统计摘要）
    /// </summary>
    Task<List<HealthStatsResponse>> GetUserStatsAsync(Guid userId);
}
