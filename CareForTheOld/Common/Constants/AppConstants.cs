namespace CareForTheOld.Common.Constants;

/// <summary>
/// 应用全局常量定义
/// 集中管理业务参数，避免魔术数字散落在各处
/// </summary>
public static class AppConstants
{
    /// <summary>
    /// 地理围栏相关常量
    /// </summary>
    public static class GeoFence
    {
        /// <summary>围栏默认半径（米），适合同社区范围的活动区域</summary>
        public const int DefaultRadiusMeters = 500;
    }

    /// <summary>
    /// 邻里互助相关常量
    /// </summary>
    public static class NeighborHelp
    {
        /// <summary>求助请求默认过期时间（分钟），超过此时间无人响应则自动关闭</summary>
        public const int DefaultExpirationMinutes = 15;

        /// <summary>广播距离阈值（米），只通知此范围内的邻居</summary>
        public const double BroadcastRadiusMeters = 500;
    }

    /// <summary>
    /// 用药提醒相关常量
    /// </summary>
    public static class Medication
    {
        /// <summary>二次提醒延迟（分钟）：首次提醒后未确认，再次强提醒</summary>
        public const int FollowUpDelayMinutes = 10;

        /// <summary>子女介入延迟（分钟）：二次提醒后仍未确认，通知子女跟进</summary>
        public const int EscalationDelayMinutes = 30;

        /// <summary>通知发送最大重试次数</summary>
        public const int MaxNotifyRetries = 3;

        /// <summary>通知发送重试间隔（秒）</summary>
        public const int NotifyRetryDelaySeconds = 1;
    }

    /// <summary>
    /// 邀请码相关常量
    /// </summary>
    public static class InviteCode
    {
        /// <summary>邀请码有效期（天），过期后需重新生成</summary>
        public const int ExpirationDays = 7;
    }

    /// <summary>
    /// 缓存相关常量
    /// </summary>
    public static class Cache
    {
        /// <summary>默认缓存过期时间（分钟），无明确过期要求时使用</summary>
        public const int DefaultExpirationMinutes = 30;
    }

    /// <summary>
    /// 安全与认证相关常量
    /// </summary>
    public static class Security
    {
        /// <summary>JWT 时钟偏移容忍时间（分钟），应对服务器间时钟差异</summary>
        public const int JwtClockSkewMinutes = 5;
    }
}
