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

        /// <summary>响应者不存在</summary>
        public const string ResponderNotFound = "响应者不存在";
    }

    /// <summary>
    /// 认证相关错误消息
    /// </summary>
    public static class Auth
    {
        /// <summary>该手机号已注册</summary>
        public const string PhoneAlreadyRegistered = "该手机号已注册";

        /// <summary>手机号或密码错误</summary>
        public const string InvalidCredentials = "手机号或密码错误";

        /// <summary>无效的刷新令牌</summary>
        public const string InvalidRefreshToken = "无效的刷新令牌";

        /// <summary>检测到安全异常，需重新登录</summary>
        public const string SecurityAnomaly = "检测到安全异常，请重新登录";

        /// <summary>刷新令牌已过期或已撤销</summary>
        public const string RefreshTokenExpired = "刷新令牌已过期或已撤销";
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

        /// <summary>只有子女才能创建家庭组</summary>
        public const string OnlyChildCanCreate = "只有子女才能创建家庭组";

        /// <summary>该用户已加入其他家庭组</summary>
        public const string UserAlreadyInOtherFamily = "该用户已加入其他家庭组";

        /// <summary>无法添加该用户（手机号未注册）</summary>
        public const string CannotAddUser = "无法添加该用户，请确认手机号正确且用户已注册";

        /// <summary>该用户已在家庭组中</summary>
        public const string UserAlreadyInFamily = "该用户已在家庭组中";

        /// <summary>不能移除家庭创建者</summary>
        public const string CannotRemoveCreator = "不能移除家庭创建者";

        /// <summary>该用户不在家庭组中</summary>
        public const string UserNotInFamily = "该用户不在家庭组中";

        /// <summary>不在任何家庭组中</summary>
        public const string NotInAnyFamily = "您不在任何家庭组中，无法发起紧急呼叫";

        /// <summary>该成员不在您的家庭中</summary>
        public const string MemberNotInFamily = "该成员不在您的家庭中";

        /// <summary>未加入家庭</summary>
        public const string NotJoinedFamily = "未加入家庭";
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

        /// <summary>该邻里圈人数已满</summary>
        public const string CircleFull = "该邻里圈人数已满";

        /// <summary>您不是该邻里圈成员</summary>
        public const string NotCircleMember = "您不是该邻里圈成员";

        /// <summary>仅圈主可以刷新邀请码</summary>
        public const string OnlyCreatorCanRefreshCode = "仅圈主可以刷新邀请码";
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

        /// <summary>求助请求状态不允许该操作</summary>
        public const string InvalidStatus = "求助请求当前状态不允许该操作";

        /// <summary>求助请求已过期</summary>
        public const string RequestExpired = "求助请求已过期";

        /// <summary>不能接受自己发起的求助</summary>
        public const string CannotAcceptOwn = "不能接受自己发起的求助";

        /// <summary>只有求助者或其子女可以取消求助</summary>
        public const string OnlyRequesterOrChildCancel = "只有求助者或其子女可以取消求助";

        /// <summary>只有求助者或其子女可以评价</summary>
        public const string OnlyRequesterOrChildRate = "只有求助者或其子女可以评价";

        /// <summary>只能评价已接受的求助请求</summary>
        public const string CanOnlyRateAccepted = "只能评价已接受的求助请求";

        /// <summary>该求助请求未被响应，无法评价</summary>
        public const string NotRespondedCannotRate = "该求助请求未被响应，无法评价";
    }

    /// <summary>
    /// 用药相关错误消息
    /// </summary>
    public static class Medication
    {
        /// <summary>用药计划不存在</summary>
        public const string PlanNotFound = "用药计划不存在";

        /// <summary>老人用户不存在</summary>
        public const string ElderNotFound = "老人用户不存在";

        /// <summary>时间格式错误</summary>
        public const string InvalidTimeFormat = "时间格式错误，正确格式如 08:00";
    }

    /// <summary>
    /// 健康相关错误消息
    /// </summary>
    public static class Health
    {
        /// <summary>健康记录不存在</summary>
        public const string RecordNotFound = "记录不存在";

        /// <summary>记录不存在或无权删除</summary>
        public const string RecordNotFoundOrNoPermission = "记录不存在或无权删除";

        /// <summary>该用户不是家庭成员</summary>
        public const string NotFamilyMember = "该用户不是家庭成员";

        /// <summary>血压记录缺少必填字段</summary>
        public const string BloodPressureRequired = "血压记录需要填写收缩压和舒张压";

        /// <summary>收缩压数值异常</summary>
        public const string SystolicOutOfRange = "收缩压数值异常（正常范围 60-300 mmHg）";

        /// <summary>舒张压数值异常</summary>
        public const string DiastolicOutOfRange = "舒张压数值异常（正常范围 30-200 mmHg）";

        /// <summary>血糖记录缺少必填字段</summary>
        public const string BloodSugarRequired = "血糖记录需要填写血糖值";

        /// <summary>血糖数值异常</summary>
        public const string BloodSugarOutOfRange = "血糖数值异常（正常范围 1.0-35.0 mmol/L）";

        /// <summary>心率记录缺少必填字段</summary>
        public const string HeartRateRequired = "心率记录需要填写心率值";

        /// <summary>心率数值异常</summary>
        public const string HeartRateOutOfRange = "心率数值异常（正常范围 30-250 次/分钟）";

        /// <summary>体温记录缺少必填字段</summary>
        public const string TemperatureRequired = "体温记录需要填写体温值";

        /// <summary>体温数值异常</summary>
        public const string TemperatureOutOfRange = "体温数值异常（正常范围 34.0-43.0 °C）";
    }

    /// <summary>
    /// 围栏相关错误消息
    /// </summary>
    public static class GeoFence
    {
        /// <summary>围栏不存在</summary>
        public const string NotFound = "围栏不存在";

        /// <summary>无权修改此围栏</summary>
        public const string NoPermissionToEdit = "无权修改此围栏";

        /// <summary>无权删除此围栏</summary>
        public const string NoPermissionToDelete = "无权删除此围栏";

        /// <summary>无权查看该老人的围栏信息</summary>
        public const string NoPermissionToView = "无权查看该老人的围栏信息";
    }

    /// <summary>
    /// 文件上传相关错误消息
    /// </summary>
    public static class FileUpload
    {
        /// <summary>未选择上传文件</summary>
        public const string NoFileSelected = "请选择要上传的头像文件";

        /// <summary>文件大小超限</summary>
        public const string FileTooLarge = "文件大小不能超过 2MB";

        /// <summary>文件格式不支持</summary>
        public const string InvalidFormat = "仅支持 JPG 和 PNG 格式的图片";

        /// <summary>文件内容类型不支持</summary>
        public const string InvalidContentType = "文件内容类型不支持";
    }

    /// <summary>
    /// 紧急呼叫相关错误消息
    /// </summary>
    public static class Emergency
    {
        /// <summary>紧急呼叫记录不存在</summary>
        public const string CallNotFound = "紧急呼叫记录不存在";

        /// <summary>该呼叫已被处理</summary>
        public const string CallAlreadyResponded = "该呼叫已被处理";

        /// <summary>不是该家庭成员，无法处理此呼叫</summary>
        public const string NotFamilyMemberForCall = "您不是该家庭成员，无法处理此呼叫";
    }

    /// <summary>
    /// 用户相关错误消息
    /// </summary>
    public static class User
    {
        /// <summary>旧密码不正确</summary>
        public const string OldPasswordIncorrect = "旧密码不正确";

        /// <summary>无权查看该用户信息</summary>
        public const string NoPermissionToView = "您不是该用户的家庭成员，无权查看";
    }
}

/// <summary>
/// 统一成功消息常量
/// 集中管理 Controller 返回的成功消息，确保表述一致
/// </summary>
public static class SuccessMessages
{
    /// <summary>认证相关成功消息</summary>
    public static class Auth
    {
        public const string RegisterSuccess = "注册成功";
        public const string LoginSuccess = "登录成功";
        public const string RefreshSuccess = "刷新成功";
    }

    /// <summary>家庭组相关成功消息</summary>
    public static class Family
    {
        public const string CreateSuccess = "创建成功";
        public const string InviteSuccess = "邀请成功";
        public const string ApplySubmitted = "申请已提交";
        public const string InviteCodeRefreshed = "邀请码已刷新";
        public const string ApproveSuccess = "审批通过";
        public const string RejectSuccess = "已拒绝";
        public const string RemoveSuccess = "移除成功";
    }

    /// <summary>围栏相关成功消息</summary>
    public static class GeoFence
    {
        public const string CreateSuccess = "围栏创建成功";
        public const string UpdateSuccess = "围栏更新成功";
        public const string DeleteSuccess = "围栏删除成功";
    }

    /// <summary>用户相关成功消息</summary>
    public static class User
    {
        public const string UpdateSuccess = "更新成功";
        public const string PasswordChanged = "密码修改成功";
        public const string AvatarUploaded = "头像上传成功";
    }

    /// <summary>用药相关成功消息</summary>
    public static class Medication
    {
        public const string CreateSuccess = "创建成功";
        public const string UpdateSuccess = "更新成功";
        public const string DeleteSuccess = "删除成功";
        public const string LogSuccess = "记录成功";
    }

    /// <summary>健康相关成功消息</summary>
    public static class Health
    {
        public const string RecordSuccess = "记录成功";
        public const string DeleteSuccess = "删除成功";
    }

    /// <summary>邻里圈相关成功消息</summary>
    public static class NeighborCircle
    {
        public const string CreateSuccess = "创建成功";
        public const string JoinSuccess = "加入成功";
        public const string LeaveSuccess = "已退出邻里圈";
        public const string InviteCodeRefreshed = "邀请码已刷新";
    }

    /// <summary>邻里互助相关成功消息</summary>
    public static class NeighborHelp
    {
        public const string AcceptSuccess = "已接受求助";
        public const string CancelSuccess = "已取消求助";
        public const string RateSuccess = "评价成功";
    }

    /// <summary>自动救援相关成功消息</summary>
    public static class AutoRescue
    {
        public const string RespondConfirmed = "已确认响应";
    }

    /// <summary>紧急呼叫相关成功消息</summary>
    public static class Emergency
    {
        public const string CallSent = "紧急呼叫已发送，已通知家人和附近邻居";
        public const string MarkHandled = "已标记处理";
    }

    /// <summary>位置相关成功消息</summary>
    public static class Location
    {
        public const string ReportSuccess = "位置上报成功";
    }

    /// <summary>设备相关成功消息</summary>
    public static class Device
    {
        public const string TokenRegistered = "设备令牌注册成功";
        public const string TokenCleared = "设备令牌已清除";
    }

    /// <summary>通知相关成功消息</summary>
    public static class Notification
    {
        public const string NotFound = "通知不存在";
        public const string MarkedRead = "已标记为已读";
        public const string AllMarkedRead = "全部标记为已读";
    }
}
