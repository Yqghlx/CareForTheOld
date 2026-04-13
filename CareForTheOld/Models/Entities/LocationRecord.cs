namespace CareForTheOld.Models.Entities;

/// <summary>
/// 位置记录实体
/// </summary>
public class LocationRecord
{
    public Guid Id { get; set; }

    /// <summary>
    /// 用户ID
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// 纬度
    /// </summary>
    public double Latitude { get; set; }

    /// <summary>
    /// 经度
    /// </summary>
    public double Longitude { get; set; }

    /// <summary>
    /// 记录时间
    /// </summary>
    public DateTime RecordedAt { get; set; } = DateTime.UtcNow;

    // 导航属性
    public User User { get; set; } = null!;
}