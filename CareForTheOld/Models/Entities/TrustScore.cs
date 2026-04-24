namespace CareForTheOld.Models.Entities;

/// <summary>
/// 信任评分实体 — 量化邻居在圈内可信度，用于求助广播优先级排序
/// </summary>
public class TrustScore
{
    public Guid Id { get; set; }

    /// <summary>用户 ID</summary>
    public Guid UserId { get; set; }

    /// <summary>所属邻里圈 ID</summary>
    public Guid CircleId { get; set; }

    /// <summary>完成互助次数</summary>
    public int TotalHelps { get; set; }

    /// <summary>平均评分（1-5）</summary>
    public decimal AvgRating { get; set; }

    /// <summary>响应率（0-1，收到通知后接单的比例）</summary>
    public decimal ResponseRate { get; set; }

    /// <summary>综合评分（0-100），算法：AvgRating×8×0.4 + Min(TotalHelps/20,1)×100×0.3 + ResponseRate×100×0.3</summary>
    public decimal Score { get; set; }

    /// <summary>上次计算时间</summary>
    public DateTime LastCalculatedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public User User { get; set; } = null!;
    public NeighborCircle Circle { get; set; } = null!;
}
