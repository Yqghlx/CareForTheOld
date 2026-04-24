using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Neighbor;

/// <summary>
/// 邻里互助评价请求
/// </summary>
public class RateHelpRequest
{
    /// <summary>评分 1-5</summary>
    [Required, Range(1, 5)]
    public int Rating { get; set; }

    /// <summary>评价内容</summary>
    [MaxLength(500)]
    public string? Comment { get; set; }
}
