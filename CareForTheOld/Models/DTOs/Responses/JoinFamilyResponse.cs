using CareForTheOld.Models.Enums;

namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 加入家庭响应（申请模式）
/// </summary>
public class JoinFamilyResponse
{
    /// <summary>
    /// 提示消息
    /// </summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// 家庭组名称
    /// </summary>
    public string FamilyName { get; set; } = string.Empty;

    /// <summary>
    /// 申请状态（Pending=待审批）
    /// </summary>
    public FamilyMemberStatus Status { get; set; }
}
