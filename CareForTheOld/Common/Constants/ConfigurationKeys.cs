namespace CareForTheOld.Common.Constants;

/// <summary>
/// 配置键常量
/// 集中管理 IConfiguration 中使用的键名字符串，防止拼写错误导致静默失败
/// </summary>
public static class ConfigurationKeys
{
    /// <summary>
    /// JWT 认证配置键
    /// </summary>
    public static class Jwt
    {
        public const string Key = "Jwt:Key";
        public const string Issuer = "Jwt:Issuer";
        public const string Audience = "Jwt:Audience";
        public const string AccessTokenExpirationMinutes = "Jwt:AccessTokenExpirationMinutes";
        public const string RefreshTokenExpirationDays = "Jwt:RefreshTokenExpirationDays";
    }

    /// <summary>
    /// 短信服务配置键
    /// </summary>
    public static class Sms
    {
        public const string Provider = "Sms:Provider";

        public static class Aliyun
        {
            public const string AccessKeyId = "Sms:Aliyun:AccessKeyId";
            public const string AccessKeySecret = "Sms:Aliyun:AccessKeySecret";
            public const string SignName = "Sms:Aliyun:SignName";
            public const string TemplateCode = "Sms:Aliyun:TemplateCode";
        }

        public static class Twilio
        {
            public const string AccountSid = "Sms:Twilio:AccountSid";
            public const string AuthToken = "Sms:Twilio:AuthToken";
            public const string FromNumber = "Sms:Twilio:FromNumber";
        }
    }

    /// <summary>
    /// Firebase 推送配置键
    /// </summary>
    public static class Firebase
    {
        public const string CredentialsPath = "Firebase:CredentialsPath";
    }

    /// <summary>
    /// CORS 跨域配置键
    /// </summary>
    public static class Cors
    {
        public const string AllowedOrigins = "Cors:AllowedOrigins";
    }

    /// <summary>
    /// 心跳检测配置键
    /// </summary>
    public static class Heartbeat
    {
        public const string TimeoutMinutes = "Heartbeat:TimeoutMinutes";
        public const string AlertCooldownMinutes = "Heartbeat:AlertCooldownMinutes";
    }

    /// <summary>
    /// 用药提醒配置键
    /// </summary>
    public static class MedicationReminder
    {
        public const string AdvanceMinutes = "MedicationReminder:AdvanceMinutes";
    }

    /// <summary>
    /// 自动救援配置键
    /// </summary>
    public static class AutoRescue
    {
        public const string DelayMinutes = "AutoRescue:DelayMinutes";
        public const string Enabled = "AutoRescue:Enabled";
    }

    /// <summary>
    /// 紧急呼叫配置键
    /// </summary>
    public static class Emergency
    {
        public const string FollowUpDelayMinutes = "Emergency:FollowUpDelayMinutes";
    }

    /// <summary>
    /// 位置服务配置键
    /// </summary>
    public static class Location
    {
        public const string AccuracyThresholdMeters = "Location:AccuracyThresholdMeters";
    }

    /// <summary>
    /// 限流策略配置键
    /// </summary>
    public static class RateLimit
    {
        public const string AuthPermitLimit = "RateLimit:AuthPermitLimit";
        public const string AuthWindow = "RateLimit:AuthWindow";
        public const string GeneralPermitLimit = "RateLimit:GeneralPermitLimit";
        public const string GeneralWindow = "RateLimit:GeneralWindow";
        public const string JoinFamilyPermitLimit = "RateLimit:JoinFamilyPermitLimit";
        public const string JoinFamilyWindow = "RateLimit:JoinFamilyWindow";
        public const string JoinCirclePermitLimit = "RateLimit:JoinCirclePermitLimit";
        public const string JoinCircleWindow = "RateLimit:JoinCircleWindow";
        public const string EmergencyPermitLimit = "RateLimit:EmergencyPermitLimit";
        public const string EmergencyWindow = "RateLimit:EmergencyWindow";
        public const string HealthPermitLimit = "RateLimit:HealthPermitLimit";
        public const string HealthWindow = "RateLimit:HealthWindow";
    }
}
