namespace CareForTheOld.Common.Constants;

/// <summary>
/// DTO 验证消息常量
/// 集中管理 DataAnnotations ErrorMessage 中的用户可见验证提示
/// </summary>
public static class ValidationMessages
{
    public static class Auth
    {
        public const string PhoneRequired = "手机号不能为空";
        public const string PhoneInvalid = "手机号格式不正确";
        public const string PasswordRequired = "密码不能为空";
        public const string NameRequired = "姓名不能为空";
        public const string NameTooLong = "姓名长度不能超过50";
        public const string BirthDateRequired = "出生日期不能为空";
        public const string RoleRequired = "角色不能为空";
        public const string RoleInvalid = "角色值无效";
        public const string RefreshTokenRequired = "刷新令牌不能为空";
    }

    public static class User
    {
        public const string OldPasswordRequired = "旧密码不能为空";
        public const string NewPasswordRequired = "新密码不能为空";
        public const string NameTooLong = "姓名长度不能超过50";
        public const string AvatarTooLong = "头像地址长度不能超过500";
    }

    public static class Location
    {
        public const string LatitudeRequired = "纬度不能为空";
        public const string LatitudeOutOfRange = "纬度范围应在 -90 到 90 之间";
        public const string LongitudeRequired = "经度不能为空";
        public const string LongitudeOutOfRange = "经度范围应在 -180 到 180 之间";
    }

    public static class Family
    {
        public const string NameRequired = "家庭组名称不能为空";
        public const string PhoneRequired = "手机号不能为空";
        public const string InviteCodeRequired = "邀请码不能为空";
        public const string InviteCodeInvalid = "邀请码为6位";
        public const string RoleRequired = "角色不能为空";
        public const string RelationshipRequired = "关系不能为空";
        public const string RelationshipTooLong = "关系描述长度不能超过20";
    }

    public static class NeighborCircle
    {
        public const string NameRequired = "圈子名称不能为空";
        public const string NameTooLong = "名称长度不能超过100";
    }
}
