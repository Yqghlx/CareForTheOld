using CareForTheOld.Models.DTOs.Requests.Medication;
using CareForTheOld.Models.DTOs.Responses;

namespace CareForTheOld.Services.Interfaces;

/// <summary>
/// 用药提醒服务接口
/// </summary>
public interface IMedicationService
{
    /// <summary>
    /// 创建用药计划
    /// </summary>
    Task<MedicationPlanResponse> CreatePlanAsync(Guid operatorId, CreateMedicationPlanRequest request);

    /// <summary>
    /// 获取老人的用药计划列表
    /// </summary>
    Task<List<MedicationPlanResponse>> GetPlansByElderAsync(Guid elderId);

    /// <summary>
    /// 更新用药计划
    /// </summary>
    Task<MedicationPlanResponse> UpdatePlanAsync(Guid planId, Guid operatorId, UpdateMedicationPlanRequest request);

    /// <summary>
    /// 删除用药计划
    /// </summary>
    Task DeletePlanAsync(Guid planId, Guid operatorId);

    /// <summary>
    /// 记录用药日志
    /// </summary>
    Task<MedicationLogResponse> RecordLogAsync(Guid operatorId, RecordMedicationLogRequest request);

    /// <summary>
    /// 获取用药日志列表
    /// </summary>
    Task<List<MedicationLogResponse>> GetLogsAsync(Guid elderId, DateOnly? date, int skip = 0, int limit = 50);

    /// <summary>
    /// 获取今日待服药列表
    /// </summary>
    Task<List<MedicationLogResponse>> GetTodayPendingAsync(Guid elderId);
}