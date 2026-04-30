namespace CareForTheOld.Models.DTOs.Responses;

/// <summary>
/// 信任排行榜条目响应
/// </summary>
public class TrustRankingResponse
{
    public int Rank { get; set; }
    public Guid UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public int TotalHelps { get; set; }
    public double AvgRating { get; set; }
    public double ResponseRate { get; set; }
    public double Score { get; set; }
}

/// <summary>
/// 个人信任评分响应
/// </summary>
public class MyTrustScoreResponse
{
    public double Score { get; set; }
}
