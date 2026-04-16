using CareForTheOld.Models.Entities;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 健康异常预警服务接口
/// </summary>
public interface IHealthAlertService
{
    /// <summary>
    /// 检查健康记录是否存在异常
    /// </summary>
    /// <param name="record">健康记录</param>
    /// <returns>异常描述消息，null 表示正常</returns>
    string? CheckAbnormal(HealthRecord record);

    /// <summary>
    /// 发送异常预警通知给老人的子女
    /// </summary>
    /// <param name="elderId">老人用户ID</param>
    /// <param name="record">异常的健康记录</param>
    /// <param name="alertMessage">异常描述消息</param>
    Task SendAlertToChildrenAsync(Guid elderId, HealthRecord record, string alertMessage);
}