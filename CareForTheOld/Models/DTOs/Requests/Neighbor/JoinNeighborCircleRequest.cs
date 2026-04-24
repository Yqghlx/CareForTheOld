using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Neighbor;

/// <summary>
/// 通过邀请码加入邻里圈请求
/// </summary>
public class JoinNeighborCircleRequest
{
    /// <summary>6 位数字邀请码</summary>
    [Required, StringLength(6, MinimumLength = 6)]
    public string InviteCode { get; set; } = string.Empty;
}
