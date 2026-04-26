using CareForTheOld.Common.Constants;
using CareForTheOld.Models.Entities;

namespace CareForTheOld.Services.Interfaces;

public interface ITrustScoreService
{
    /// <summary>获取用户在指定圈的信任评分</summary>
    Task<decimal> GetUserScoreAsync(Guid userId, Guid circleId);

    /// <summary>获取圈内信任排行榜</summary>
    Task<IReadOnlyList<TrustScore>> GetCircleRankingAsync(Guid circleId, int top = AppConstants.Pagination.DefaultHistoryPageSize);

    /// <summary>重新计算所有信任评分（Hangfire 每日定时调用）</summary>
    Task RecalculateAllScoresAsync();

    /// <summary>互助完成后即时更新评分</summary>
    Task OnHelpCompletedAsync(Guid helpRequestId, Guid responderId);
}
