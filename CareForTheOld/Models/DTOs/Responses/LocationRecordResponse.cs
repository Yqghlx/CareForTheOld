namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>位置记录响应</summary>
public class LocationRecordResponse
{
    /// <summary>记录ID</summary>
    public Guid Id { get; set; }
    /// <summary>用户ID</summary>
    public Guid UserId { get; set; }
    /// <summary>用户姓名</summary>
    public string? RealName { get; set; }
    /// <summary>纬度</summary>
    public double Latitude { get; set; }
    /// <summary>经度</summary>
    public double Longitude { get; set; }
    /// <summary>记录时间</summary>
    public DateTime RecordedAt { get; set; }

    /// <summary>
    /// 格式化时间
    /// </summary>
    public string FormattedTime => RecordedAt.ToString("yyyy-MM-dd HH:mm");
}