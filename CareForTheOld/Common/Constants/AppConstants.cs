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

    /// <summary>
    /// 文件上传相关常量
    /// </summary>
    public static class FileUpload
    {
        /// <summary>允许的头像文件扩展名</summary>
        public static readonly HashSet<string> AllowedAvatarExtensions = new(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png" };

        /// <summary>允许的头像 MIME 内容类型</summary>
        public static readonly HashSet<string> AllowedAvatarContentTypes = new(StringComparer.OrdinalIgnoreCase) { "image/jpeg", "image/png" };

        /// <summary>最大文件大小（字节），默认 2 MB</summary>
        public const long MaxAvatarSizeBytes = 2 * 1024 * 1024;
    }

    /// <summary>
    /// 通知类型常量
    /// 集中管理通知类型字符串，防止拼写错误导致通知静默失败
    /// </summary>
    public static class NotificationTypes
    {
        /// <summary>自动救援告警通知（子女端）</summary>
        public const string AutoRescueAlert = "AutoRescueAlert";

        /// <summary>自动救援邻里广播通知（子女端）</summary>
        public const string AutoRescueBroadcast = "AutoRescueBroadcast";

        /// <summary>电子围栏超出预警通知</summary>
        public const string GeoFenceAlert = "GeoFenceAlert";

        /// <summary>紧急呼叫通知</summary>
        public const string EmergencyCall = "EmergencyCall";

        /// <summary>紧急呼叫二次提醒通知</summary>
        public const string EmergencyCallReminder = "EmergencyCallReminder";

        /// <summary>紧急呼叫 FCM 推送类型</summary>
        public const string EmergencyCallFcm = "emergency_call";

        /// <summary>紧急呼叫二次提醒 FCM 推送类型</summary>
        public const string EmergencyReminderFcm = "emergency_reminder";
    }

    /// <summary>
    /// 告警级别常量
    /// 统一通知中使用的告警严重度标识
    /// </summary>
    public static class AlertLevels
    {
        /// <summary>严重 — 需要立即处理</summary>
        public const string Critical = "Critical";

        /// <summary>警告 — 需要尽快关注</summary>
        public const string Warning = "Warning";

        /// <summary>注意 — 轻度异常提醒</summary>
        public const string Caution = "Caution";
    }

    /// <summary>
    /// SignalR 组名前缀
    /// 集中管理 SignalR 组名格式，确保 Hub 和 Service 使用一致的组名
    /// </summary>
    public static class SignalRGroups
    {
        /// <summary>家庭组前缀，完整组名格式：family_{familyId}</summary>
        public const string FamilyPrefix = "family_";

        /// <summary>邻里圈组前缀，完整组名格式：circle_{circleId}</summary>
        public const string CirclePrefix = "circle_";

        /// <summary>生成家庭组名</summary>
        public static string FamilyGroupName(Guid familyId) => $"{FamilyPrefix}{familyId}";

        /// <summary>生成邻里圈组名</summary>
        public static string CircleGroupName(Guid circleId) => $"{CirclePrefix}{circleId}";
    }
}
