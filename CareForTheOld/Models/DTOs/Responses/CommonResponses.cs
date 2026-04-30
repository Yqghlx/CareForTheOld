namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 未读数量响应
/// </summary>
public class UnreadCountResponse
{
    public int Count { get; set; }
}

/// <summary>
/// 操作结果响应（用于标记已读、确认响应等简单成功/失败场景）
/// </summary>
public class OperationResultResponse
{
    public bool Success { get; set; }
}
