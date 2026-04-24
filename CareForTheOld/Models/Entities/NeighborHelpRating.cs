namespace CareForTheOld.Models.Entities;

/// <summary>
/// 邻里互助评价实体
/// </summary>
public class NeighborHelpRating
{
    public Guid Id { get; set; }
    public Guid HelpRequestId { get; set; }

    /// <summary>评价人 ID（老人或其子女）</summary>
    public Guid RaterId { get; set; }

    /// <summary>被评价人 ID（响应的邻居）</summary>
    public Guid RateeId { get; set; }

    /// <summary>评分 1-5</summary>
    public int Rating { get; set; }

    /// <summary>评价内容</summary>
    public string? Comment { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public NeighborHelpRequest HelpRequest { get; set; } = null!;
    public User Rater { get; set; } = null!;
    public User Ratee { get; set; } = null!;
}
