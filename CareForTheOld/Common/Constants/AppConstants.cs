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
    /// 位置服务相关常量
    /// </summary>
    public static class Location
    {
        /// <summary>GPS 精度阈值（米），精度超过此值时跳过围栏检查，防止室内飘移误报</summary>
        public const double DefaultAccuracyThresholdMeters = 100.0;
    }

    /// <summary>
    /// 紧急呼叫相关常量
    /// </summary>
    public static class Emergency
    {
        /// <summary>二次提醒延迟（分钟）：首次呼叫后未响应，再次提醒子女</summary>
        public const int FollowUpDelayMinutes = 3;
    }

    /// <summary>
    /// 自动救援相关常量
    /// </summary>
    public static class AutoRescue
    {
        /// <summary>子女响应等待时间（分钟），超时后自动触发邻里广播</summary>
        public const int DefaultDelayMinutes = 5;
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
    /// 邻里圈相关常量
    /// </summary>
    public static class NeighborCircle
    {
        /// <summary>附近成员默认搜索半径（米），与围栏默认半径一致</summary>
        public const int DefaultMemberRadiusMeters = 500;

        /// <summary>附近圈子搜索半径（米）</summary>
        public const int SearchRadiusMeters = 2000;

        /// <summary>搜索返回最大结果数</summary>
        public const int SearchMaxResults = 20;
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

        /// <summary>围栏数据缓存过期时间（分钟），围栏变更频率较低可适当延长</summary>
        public const int GeoFenceExpirationMinutes = 10;
    }

    /// <summary>
    /// 安全与认证相关常量
    /// </summary>
    public static class Security
    {
        /// <summary>JWT 时钟偏移容忍时间（分钟），应对服务器间时钟差异</summary>
        public const int JwtClockSkewMinutes = 5;

        /// <summary>JWT 访问令牌默认过期时间（分钟）</summary>
        public const int JwtAccessTokenExpirationMinutes = 60;

        /// <summary>JWT 刷新令牌默认过期时间（天）</summary>
        public const int JwtRefreshTokenExpirationDays = 30;
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

        /// <summary>用药紧急提醒通知（老人端）</summary>
        public const string MedicationReminderUrgent = "MedicationReminderUrgent";

        /// <summary>用药未服药通知子女</summary>
        public const string MedicationReminderFamily = "MedicationReminderFamily";

        /// <summary>用药漏服记录通知</summary>
        public const string MedicationMissed = "MedicationMissed";

        /// <summary>邻里求助广播通知</summary>
        public const string NeighborHelpRequest = "NeighborHelpRequest";

        /// <summary>邻里求助已接受通知</summary>
        public const string NeighborHelpAccepted = "NeighborHelpAccepted";

        /// <summary>邻里求助已完成通知</summary>
        public const string NeighborHelpResolved = "NeighborHelpResolved";

        /// <summary>邻里求助已取消通知</summary>
        public const string NeighborHelpCancelled = "NeighborHelpCancelled";

        /// <summary>健康异常预警通知</summary>
        public const string HealthAlert = "HealthAlert";

        /// <summary>老人离线告警通知</summary>
        public const string ElderOffline = "ElderOffline";
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

        /// <summary>用户组前缀，完整组名格式：user_{userId}</summary>
        public const string UserPrefix = "user_";

        /// <summary>生成家庭组名</summary>
        public static string FamilyGroupName(Guid familyId) => $"{FamilyPrefix}{familyId}";

        /// <summary>生成邻里圈组名</summary>
        public static string CircleGroupName(Guid circleId) => $"{CirclePrefix}{circleId}";

        /// <summary>生成用户组名</summary>
        public static string UserGroupName(Guid userId) => $"{UserPrefix}{userId}";

        /// <summary>生成用户组名（string 重载，用于 SignalR Hub 中 UserIdentifier）</summary>
        public static string UserGroupName(string userId) => $"{UserPrefix}{userId}";
    }

    /// <summary>
    /// 信任评分算法参数
    /// 评分公式：AvgRating×RatingMultiplier×RatingWeight + Min(TotalHelps/MaxHelpsCap,1)×100×HelpsWeight + ResponseRate×100×ResponseWeight
    /// </summary>
    public static class TrustScore
    {
        /// <summary>评分权重：评分均值占比（40%）</summary>
        public const decimal RatingWeight = 0.4m;

        /// <summary>评分权重：互助次数占比（30%）</summary>
        public const decimal HelpsWeight = 0.3m;

        /// <summary>评分权重：响应率占比（30%）</summary>
        public const decimal ResponseWeight = 0.3m;

        /// <summary>评分归一化乘数：将 1-5 评分映射到 0-40</summary>
        public const decimal RatingMultiplier = 8m;

        /// <summary>互助次数封顶值，超过此数不再额外加分</summary>
        public const int MaxHelpsCap = 20;
    }

    /// <summary>
    /// 健康阈值常量
    /// 定义各类健康指标的正常范围和严重阈值，用于健康异常检测和预警
    /// </summary>
    public static class HealthThresholds
    {
        /// <summary>血压收缩压正常范围下限（mmHg）</summary>
        public const int BloodPressureSystolicMin = 90;

        /// <summary>血压收缩压正常范围上限（mmHg）</summary>
        public const int BloodPressureSystolicMax = 140;

        /// <summary>血压舒张压正常范围下限（mmHg）</summary>
        public const int BloodPressureDiastolicMin = 60;

        /// <summary>血压舒张压正常范围上限（mmHg）</summary>
        public const int BloodPressureDiastolicMax = 90;

        /// <summary>血压严重偏高收缩压阈值（mmHg）— 高血压急症</summary>
        public const int BloodPressureCriticalHighSystolic = 180;

        /// <summary>血压严重偏高舒张压阈值（mmHg）— 高血压急症</summary>
        public const int BloodPressureCriticalHighDiastolic = 120;

        /// <summary>血压中度偏高收缩压阈值（mmHg）— 中度高血压</summary>
        public const int BloodPressureModerateHighSystolic = 160;

        /// <summary>血压中度偏高舒张压阈值（mmHg）— 中度高血压</summary>
        public const int BloodPressureModerateHighDiastolic = 100;

        /// <summary>血压严重偏低收缩压阈值（mmHg）— 休克风险</summary>
        public const int BloodPressureCriticalLowSystolic = 80;

        /// <summary>血压严重偏低舒张压阈值（mmHg）— 休克风险</summary>
        public const int BloodPressureCriticalLowDiastolic = 50;

        /// <summary>血糖正常范围下限（mmol/L，空腹）</summary>
        public const decimal BloodSugarMin = 3.9m;

        /// <summary>血糖正常范围上限（mmol/L，空腹）</summary>
        public const decimal BloodSugarMax = 6.1m;

        /// <summary>血糖严重偏高阈值（mmol/L）— 糖尿病诊断标准</summary>
        public const decimal BloodSugarCriticalHigh = 11.1m;

        /// <summary>血糖中度偏高阈值（mmol/L）— 糖耐量异常</summary>
        public const decimal BloodSugarModerateHigh = 7.0m;

        /// <summary>血糖严重偏低阈值（mmol/L）— 低血糖危险</summary>
        public const decimal BloodSugarCriticalLow = 2.8m;

        /// <summary>心率正常范围下限（次/分）</summary>
        public const int HeartRateMin = 60;

        /// <summary>心率正常范围上限（次/分）</summary>
        public const int HeartRateMax = 100;

        /// <summary>心率严重过快阈值（次/分）— 心动过速急症</summary>
        public const int HeartRateCriticalHigh = 150;

        /// <summary>心率严重过慢阈值（次/分）— 心动过缓急症</summary>
        public const int HeartRateCriticalLow = 40;

        /// <summary>体温正常范围下限（°C）</summary>
        public const decimal TemperatureMin = 36.0m;

        /// <summary>体温正常范围上限（°C）</summary>
        public const decimal TemperatureMax = 37.3m;

        /// <summary>体温高烧阈值（°C）— 高热急症</summary>
        public const decimal TemperatureCriticalHigh = 39.0m;

        /// <summary>体温发烧阈值（°C）— 中度发热</summary>
        public const decimal TemperatureModerateHigh = 38.0m;

        /// <summary>体温严重偏低阈值（°C）— 低体温症</summary>
        public const decimal TemperatureCriticalLow = 35.0m;
    }
}
