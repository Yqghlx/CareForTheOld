namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 位置记录响应
/// </summary>
public class LocationRecordResponse
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string? RealName { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public DateTime RecordedAt { get; set; }

    /// <summary>
    /// 格式化时间
    /// </summary>
    public string FormattedTime => RecordedAt.ToString("yyyy-MM-dd HH:mm");
}