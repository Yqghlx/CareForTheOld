namespace CareForTheOld.Common.Constants;

/// <summary>
/// 统一错误消息常量
/// 集中管理业务异常消息，确保跨服务表述一致，便于维护
/// </summary>
public static class ErrorMessages
{
    /// <summary>
    /// 通用错误消息
    /// </summary>
    public static class Common
    {
        /// <summary>找不到指定用户</summary>
        public const string UserNotFound = "用户不存在";
    }

    /// <summary>
    /// 家庭组相关错误消息
    /// </summary>
    public static class Family
    {
        /// <summary>用户已加入家庭组，不能重复创建</summary>
        public const string AlreadyInFamily = "您已加入家庭组，不能重复创建";

        /// <summary>用户已提交申请或已加入家庭组</summary>
        public const string AlreadyAppliedOrJoined = "您已提交加入申请或已加入家庭组，不能重复申请";

        /// <summary>家庭组不存在</summary>
        public const string FamilyNotFound = "家庭组不存在";

        /// <summary>不是该家庭成员</summary>
        public const string NotFamilyMember = "您不是该家庭成员";

        /// <summary>不是该老人的家庭成员</summary>
        public const string NotElderFamilyMember = "您不是该老人的家庭成员，无权操作";

        /// <summary>未找到该待审批成员</summary>
        public const string PendingMemberNotFound = "未找到该待审批成员";

        /// <summary>仅子女可以审批成员</summary>
        public const string OnlyChildCanApprove = "仅子女可以审批成员";

        /// <summary>邀请码无效</summary>
        public const string InvalidInviteCode = "邀请码无效，请检查后重试";

        /// <summary>邀请码已过期</summary>
        public const string InviteCodeExpired = "邀请码已过期，请联系家庭创建者获取新邀请码";

        /// <summary>仅家庭创建者可操作</summary>
        public const string OnlyCreatorCanOperate = "仅家庭创建者可以{0}";
    }

    /// <summary>
    /// 邻里圈相关错误消息
    /// </summary>
    public static class NeighborCircle
    {
        /// <summary>已加入邻里圈，不能重复创建</summary>
        public const string AlreadyInCircleCreate = "您已加入邻里圈，不能重复创建";

        /// <summary>已加入邻里圈，不能重复加入</summary>
        public const string AlreadyInCircleJoin = "您已加入邻里圈，不能重复加入";

        /// <summary>邻里圈不存在</summary>
        public const string CircleNotFound = "邻里圈不存在";

        /// <summary>邀请码无效</summary>
        public const string InvalidInviteCode = "邀请码无效，请检查后重试";

        /// <summary>邀请码已过期</summary>
        public const string InviteCodeExpired = "邀请码已过期，请联系圈主获取新邀请码";
    }

    /// <summary>
    /// 邻里互助相关错误消息
    /// </summary>
    public static class NeighborHelp
    {
        /// <summary>求助请求不存在</summary>
        public const string RequestNotFound = "求助请求不存在";

        /// <summary>已评价过该求助请求</summary>
        public const string AlreadyRated = "您已评价过该求助请求";
    }

    /// <summary>
    /// 用药相关错误消息
    /// </summary>
    public static class Medication
    {
        /// <summary>用药计划不存在</summary>
        public const string PlanNotFound = "用药计划不存在";
    }

    /// <summary>
    /// 健康相关错误消息
    /// </summary>
    public static class Health
    {
        /// <summary>健康记录不存在</summary>
        public const string RecordNotFound = "记录不存在";
    }

    /// <summary>
    /// 围栏相关错误消息
    /// </summary>
    public static class GeoFence
    {
        /// <summary>围栏不存在</summary>
        public const string NotFound = "围栏不存在";
    }
}
