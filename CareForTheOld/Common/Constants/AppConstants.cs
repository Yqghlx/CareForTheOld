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

        /// <summary>距离显示单位阈值（米），超过此值以公里为单位显示</summary>
        public const int DistanceDisplayThresholdMeters = 1000;

        /// <summary>公里单位后缀</summary>
        public const string KilometerUnit = "公里";

        /// <summary>米单位后缀</summary>
        public const string MeterUnit = "米";
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

        /// <summary>后台检查轮询间隔（分钟）</summary>
        public const int CheckIntervalMinutes = 1;
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

        /// <summary>围栏缓存键前缀，完整键格式：geofence:{elderId}</summary>
        public const string GeoFencePrefix = "geofence:";

        /// <summary>用户缓存键前缀，完整键格式：user:{userId}</summary>
        public const string UserPrefix = "user:";
    }

    /// <summary>
    /// 分页相关常量
    /// </summary>
    public static class Pagination
    {
        /// <summary>每页最小条数</summary>
        public const int MinPageSize = 1;

        /// <summary>每页最大条数</summary>
        public const int MaxPageSize = 100;

        /// <summary>默认每页条数</summary>
        public const int DefaultPageSize = 50;

        /// <summary>历史记录默认每页条数（数据量较大时使用）</summary>
        public const int DefaultHistoryPageSize = 20;

        /// <summary>默认跳过条数</summary>
        public const int DefaultSkip = 0;
    }

    /// <summary>
    /// FCM 推送相关常量
    /// </summary>
    public static class Fcm
    {
        /// <summary>FCM multicast 单批次最大 token 数量</summary>
        public const int MaxBatchSize = 500;
    }

    /// <summary>
    /// Outbox 投递相关常量
    /// </summary>
    public static class Outbox
    {
        /// <summary>消息投递最大重试次数，超过后标记为 Failed</summary>
        public const int MaxRetries = 5;

        /// <summary>每次批量处理的最大消息数</summary>
        public const int BatchSize = 50;
    }

    /// <summary>
    /// 安全与认证相关常量
    /// </summary>
    public static class Security
    {
        /// <summary>HSTS 最大缓存天数（浏览器在此期间强制 HTTPS）</summary>
        public const int HstsMaxAgeDays = 365;

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

        /// <summary>家庭加入申请通知（子女端）</summary>
        public const string FamilyJoinRequest = "FamilyJoinRequest";

        /// <summary>家庭加入申请已批准通知（申请人端）</summary>
        public const string FamilyJoinApproved = "FamilyJoinApproved";

        /// <summary>家庭加入申请已拒绝通知（申请人端）</summary>
        public const string FamilyJoinRejected = "FamilyJoinRejected";
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

        /// <summary>评分显示的小数位数</summary>
        public const int DisplayDecimalPlaces = 1;
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

    /// <summary>
    /// 健康指标单位常量
    /// 集中管理健康数据展示所需的单位字符串
    /// </summary>
    public static class HealthUnits
    {
        /// <summary>血压单位（毫米汞柱）</summary>
        public const string BloodPressure = "mmHg";

        /// <summary>血糖单位（毫摩尔/升）</summary>
        public const string BloodSugar = "mmol/L";

        /// <summary>心率单位（次/分钟）</summary>
        public const string HeartRate = "次/分";

        /// <summary>体温单位（摄氏度）</summary>
        public const string Temperature = "°C";
    }

    /// <summary>
    /// 健康类型中文名称
    /// 统一管理健康类型的中文标签，避免多处重复映射
    /// </summary>
    public static class HealthTypeLabels
    {
        /// <summary>血压</summary>
        public const string BloodPressure = "血压";

        /// <summary>血糖</summary>
        public const string BloodSugar = "血糖";

        /// <summary>心率</summary>
        public const string HeartRate = "心率";

        /// <summary>体温</summary>
        public const string Temperature = "体温";

        /// <summary>通用默认名称（老人未设置真实姓名时使用）</summary>
        public const string DefaultElderName = "老人";
    }

    /// <summary>健康统计时间范围常量</summary>
    public static class HealthStatsDays
    {
        /// <summary>近期统计天数（7天）</summary>
        public const int RecentDays = 7;

        /// <summary>长期统计天数（30天）</summary>
        public const int LongTermDays = 30;

        /// <summary>趋势上升消息模板（占位符：类型名称、百分比）</summary>
        public const string TrendRisingTemplate = "近7天{0}均值较30天均值升高约{1}%，请关注";

        /// <summary>趋势下降消息模板（占位符：类型名称、百分比）</summary>
        public const string TrendFallingTemplate = "近7天{0}均值较30天均值降低约{1}%，请关注";

        /// <summary>血压趋势关注阈值（百分比），超过此值需提醒关注</summary>
        public const double BloodPressureTrendThresholdPercent = 8.0;

        /// <summary>血糖趋势关注阈值（百分比），超过此值需提醒关注</summary>
        public const double BloodSugarTrendThresholdPercent = 10.0;

        /// <summary>心率趋势关注阈值（百分比），超过此值需提醒关注</summary>
        public const double HeartRateTrendThresholdPercent = 10.0;

        /// <summary>体温趋势关注阈值（百分比），超过此值需提醒关注</summary>
        public const double TemperatureTrendThresholdPercent = 1.0;
    }

    /// <summary>
    /// 健康报告相关常量
    /// </summary>
    public static class HealthReport
    {
        /// <summary>PDF 报告中显示的最大记录条数</summary>
        public const int MaxPdfRecords = 20;
    }

    /// <summary>
    /// 安全令牌相关常量
    /// </summary>
    public static class SecurityToken
    {
        /// <summary>刷新令牌随机字节长度</summary>
        public const int RefreshTokenBytes = 64;

        /// <summary>JWT 密钥最小长度（字节），低于此值视为不安全</summary>
        public const int MinKeyLengthBytes = 32;
    }

    /// <summary>
    /// 异常检测评估阈值常量
    /// 变异系数（CV）用于衡量数据波动性：CV = 标准差 / 均值
    /// </summary>
    public static class AnomalyEvaluation
    {
        /// <summary>变异系数极佳阈值（CV &lt; 5%）：波动极小，控制极佳</summary>
        public const double CoefficientOfVariationExcellent = 0.05;

        /// <summary>变异系数良好阈值（CV &lt; 10%）：波动在正常范围</summary>
        public const double CoefficientOfVariationGood = 0.10;

        /// <summary>质量评价 - 极佳</summary>
        public const string QualityExcellent = "极佳";

        /// <summary>质量评价 - 良好</summary>
        public const string QualityGood = "良好";

        /// <summary>质量评价 - 平稳</summary>
        public const string QualityStable = "平稳";

        /// <summary>默认健康指标名称</summary>
        public const string DefaultHealthLabel = "健康指标";

        /// <summary>正面反馈最少所需天数（基线稳定性评估）</summary>
        public const int MinimumPositiveFeedbackDays = 5;

        /// <summary>趋势判定阈值（百分比），超过此值视为上升/下降趋势</summary>
        public const double TrendDirectionThresholdPercent = 5.0;

        /// <summary>持续偏高/偏低的严重度权重系数</summary>
        public const double ContinuousSeverityWeight = 10.0;

        /// <summary>波动性的严重度权重系数</summary>
        public const double VolatilitySeverityWeight = 20.0;

        /// <summary>关键健康类型（血压、血糖）的严重度权重倍率</summary>
        public const double CriticalTypeWeight = 1.5;

        /// <summary>普通健康类型的严重度权重倍率</summary>
        public const double NormalTypeWeight = 1.0;

        /// <summary>严重度评分最大值</summary>
        public const double MaxSeverityScore = 100.0;

        /// <summary>异常检测查询的最大记录数</summary>
        public const int MaxQueryRecords = 100;

        /// <summary>异常检测所需的最少记录数，低于此数量无法进行有效分析</summary>
        public const int MinimumRecords = 5;
    }

    /// <summary>
    /// 健康数据输入验证范围
    /// 定义极端异常值的拒绝阈值，超出此范围的值视为输入错误而非真实生理数据
    /// </summary>
    public static class HealthInputValidation
    {
        /// <summary>收缩压输入下限（mmHg）</summary>
        public const int SystolicMin = 60;

        /// <summary>收缩压输入上限（mmHg）</summary>
        public const int SystolicMax = 300;

        /// <summary>舒张压输入下限（mmHg）</summary>
        public const int DiastolicMin = 30;

        /// <summary>舒张压输入上限（mmHg）</summary>
        public const int DiastolicMax = 200;

        /// <summary>血糖输入下限（mmol/L）</summary>
        public const decimal BloodSugarMin = 1.0m;

        /// <summary>血糖输入上限（mmol/L）</summary>
        public const decimal BloodSugarMax = 35.0m;

        /// <summary>心率输入下限（次/分）</summary>
        public const int HeartRateMin = 30;

        /// <summary>心率输入上限（次/分）</summary>
        public const int HeartRateMax = 250;

        /// <summary>体温输入下限（°C）</summary>
        public const decimal TemperatureMin = 34.0m;

        /// <summary>体温输入上限（°C）</summary>
        public const decimal TemperatureMax = 43.0m;
    }

    /// <summary>
    /// PDF 报告颜色常量
    /// 集中管理健康报告 PDF 生成中的颜色值，确保视觉一致性
    /// </summary>
    public static class PdfColors
    {
        /// <summary>文本颜色</summary>
        public static class Text
        {
            public const string TitleBlue = "#1976D2";
            public const string SummaryBlue = "#1565C0";
            public const string SuggestionGreen = "#2E7D32";
            public const string Secondary = "#666666";
            public const string Normal = "#000000";
        }

        /// <summary>背景颜色</summary>
        public static class Background
        {
            public const string TableHeader = "#E0E0E0";
            public const string AbnormalRow = "#FFEBEE";
            public const string NormalRow = "#FFFFFF";
        }

        /// <summary>边框颜色</summary>
        public static class Border
        {
            public const string Divider = "#CCCCCC";
            public const string TableCell = "#BDBDBD";
        }

        /// <summary>健康类型专用颜色</summary>
        public static class HealthType
        {
            public const string BloodPressure = "#C62828";
            public const string BloodSugar = "#1565C0";
            public const string HeartRate = "#6A1B9A";
            public const string Temperature = "#E65100";
        }
    }

    /// <summary>
    /// MIME 类型常量
    /// </summary>
    public static class MimeTypes
    {
        /// <summary>PDF 文件</summary>
        public const string Pdf = "application/pdf";

        /// <summary>JSON</summary>
        public const string Json = "application/json";
    }

    /// <summary>
    /// 文件存储目录常量
    /// </summary>
    public static class FileDirectories
    {
        /// <summary>头像文件目录</summary>
        public const string Avatars = "avatars";
    }

    /// <summary>
    /// 设备平台常量
    /// </summary>
    public static class DevicePlatforms
    {
        /// <summary>Android 平台标识</summary>
        public const string Android = "android";

        /// <summary>iOS 平台标识</summary>
        public const string IOS = "ios";
    }
}
