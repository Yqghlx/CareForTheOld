namespace CareForTheOld.Common.Constants;

/// <summary>
/// 统一错误消息常量
/// 集中管理业务异常消息，确保跨服务表述一致，便于维护
/// </summary>
public static class ErrorMessages
{
    /// <summary>
    /// 参数验证错误消息
    /// </summary>
    public static class Validation
    {
        /// <summary>缓存键不能为空</summary>
        public const string CacheKeyRequired = "缓存键不能为空";

        /// <summary>推送标题不能为空</summary>
        public const string PushTitleRequired = "推送标题不能为空";

        /// <summary>推送内容不能为空</summary>
        public const string PushBodyRequired = "推送内容不能为空";

        /// <summary>文件目录名不能为空</summary>
        public const string FileDirectoryRequired = "文件目录名不能为空";

        /// <summary>文件名不能为空</summary>
        public const string FileNameRequired = "文件名不能为空";

        /// <summary>文件流不能为空</summary>
        public const string FileStreamRequired = "文件流不能为空";

        /// <summary>内容类型不能为空</summary>
        public const string ContentTypeRequired = "内容类型不能为空";
    }

    /// <summary>
    /// 通用错误消息
    /// </summary>
    public static class Common
    {
        /// <summary>找不到指定用户</summary>
        public const string UserNotFound = "用户不存在";

        /// <summary>响应者不存在</summary>
        public const string ResponderNotFound = "响应者不存在";

        /// <summary>无法获取用户身份</summary>
        public const string UserIdentityNotFound = "无法获取用户身份，请重新登录";
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

        /// <summary>Token 已被吊销，需重新登录</summary>
        public const string TokenRevoked = "登录已失效，请重新登录";
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

        /// <summary>老人用户信息异常</summary>
        public const string ElderUserInfoInvalid = "老人用户信息异常，请联系管理员";
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

    /// <summary>
    /// 自动救援相关错误消息
    /// </summary>
    public static class AutoRescue
    {
        /// <summary>救援记录不存在</summary>
        public const string RecordNotFound = "救援记录不存在";

        /// <summary>救援记录状态不允许响应</summary>
        public const string InvalidStatusToRespond = "救援记录当前状态不允许响应";

        /// <summary>只有子女可以响应救援</summary>
        public const string OnlyChildCanRespond = "只有该家庭的子女可以响应";
    }

    /// <summary>
    /// 文件存储相关错误消息
    /// </summary>
    public static class FileStorage
    {
        /// <summary>非法的文件路径</summary>
        public const string IllegalFilePath = "非法的文件路径";
    }

    /// <summary>
    /// 设备相关错误消息
    /// </summary>
    public static class Device
    {
        /// <summary>设备令牌不能为空</summary>
        public const string TokenRequired = "设备令牌不能为空";

        /// <summary>设备令牌长度超限</summary>
        public const string TokenTooLong = "设备令牌长度不能超过512";
    }

    /// <summary>
    /// 短信服务相关错误消息
    /// </summary>
    public static class Sms
    {
        /// <summary>短信服务配置缺失</summary>
        public const string ConfigMissing = "短信服务配置缺失";

        /// <summary>手机号需要国际格式（如 +8613800138000）</summary>
        public const string PhoneFormatInternational = "手机号格式不正确，需要国际格式";

        /// <summary>短信发送失败（通用描述，不暴露内部异常详情）</summary>
        public const string SendFailed = "短信发送失败";
    }

    /// <summary>
    /// 配置相关错误消息
    /// </summary>
    public static class Configuration
    {
        /// <summary>JWT 密钥环境变量未配置</summary>
        public const string JwtSecretKeyNotConfiguredInEnv = "生产环境必须通过环境变量配置 JWT 密钥";

        /// <summary>JWT 密钥配置文件未配置</summary>
        public const string JwtSecretKeyNotConfiguredInConfig = "JWT 密钥未配置或长度不足 32 字符";
    }

    /// <summary>
    /// 中间件相关错误消息
    /// </summary>
    public static class Middleware
    {
        /// <summary>资源未找到</summary>
        public const string NotFound = "资源未找到";

        /// <summary>未授权</summary>
        public const string Unauthorized = "未授权";

        /// <summary>请求参数错误</summary>
        public const string BadRequest = "请求参数错误";

        /// <summary>服务器内部错误</summary>
        public const string InternalError = "服务器内部错误";

        /// <summary>服务暂时不可用（超时、网络故障等临时性问题）</summary>
        public const string ServiceUnavailable = "服务暂时不可用，请稍后重试";
    }

    /// <summary>
    /// OSS 存储相关错误消息
    /// </summary>
    public static class Oss
    {
        /// <summary>OSS Endpoint 环境变量未配置</summary>
        public const string EndpointNotConfigured = "OSS_ENDPOINT 环境变量未配置";

        /// <summary>OSS Access Key ID 环境变量未配置</summary>
        public const string AccessKeyIdNotConfigured = "OSS_ACCESS_KEY_ID 环境变量未配置";

        /// <summary>OSS Access Key Secret 环境变量未配置</summary>
        public const string AccessKeySecretNotConfigured = "OSS_ACCESS_KEY_SECRET 环境变量未配置";

        /// <summary>OSS Bucket Name 环境变量未配置</summary>
        public const string BucketNameNotConfigured = "OSS_BUCKET_NAME 环境变量未配置";
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
        public const string LogoutSuccess = "登出成功";
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
        public const string InsufficientRecordsForAnomaly = "健康记录数不足，无法进行异常检测";
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

    /// <summary>通用操作成功消息</summary>
    public static class Operation
    {
        /// <summary>默认操作成功消息</summary>
        public const string Success = "操作成功";
    }
}

/// <summary>
/// 统一通知消息常量
/// 集中管理 Service 层发送的通知 Title/Content 模板，确保表述一致
/// </summary>
public static class NotificationMessages
{
    /// <summary>家庭相关通知</summary>
    public static class Family
    {
        /// <summary>家庭加入申请标题</summary>
        public const string JoinRequestTitle = "家庭加入申请";

        /// <summary>加入申请内容模板（占位符：申请人姓名、关系、家庭名称）</summary>
        public const string JoinRequestContentTemplate = "{0}（{1}）申请加入{2}，请审批";

        /// <summary>加入申请已通过标题</summary>
        public const string JoinApprovedTitle = "加入申请已通过";

        /// <summary>加入申请已通过内容模板（占位符：操作者姓名、家庭名称）</summary>
        public const string JoinApprovedContentTemplate = "{0}已同意您加入{1}";

        /// <summary>加入申请被拒绝标题</summary>
        public const string JoinRejectedTitle = "加入申请被拒绝";

        /// <summary>加入申请被拒绝内容（占位符：家庭名称）</summary>
        public const string JoinRejectedContentTemplate = "{0}的管理员拒绝了您的加入申请";

        /// <summary>申请已提交默认回复</summary>
        public const string JoinAppliedMessage = "申请已提交，等待子女审批";

        /// <summary>创建者角色名称</summary>
        public const string CreatorRole = "创建者";

        /// <summary>默认家庭名称（信息缺失时使用）</summary>
        public const string DefaultFamilyName = "家庭组";

        /// <summary>默认操作者名称（信息缺失时使用）</summary>
        public const string DefaultOperatorName = "管理员";
    }

    /// <summary>邻里互助相关通知</summary>
    public static class NeighborHelp
    {
        /// <summary>邻居紧急求助标题</summary>
        public const string EmergencyRequestTitle = "邻居紧急求助";

        /// <summary>邻居正在赶来标题</summary>
        public const string HelperComingTitle = "邻居正在赶来";

        /// <summary>邻居已响应紧急呼叫标题</summary>
        public const string HelperRespondedTitle = "邻居已响应紧急呼叫";

        /// <summary>求助已被响应标题</summary>
        public const string RequestRespondedTitle = "求助已被响应";

        /// <summary>求助已取消标题</summary>
        public const string RequestCancelledTitle = "求助已取消";

        /// <summary>紧急求助内容（占位符：老人姓名）</summary>
        public const string EmergencyRequestContentTemplate = "{0}发起紧急求助，请帮忙！";

        /// <summary>紧急求助内容（邻居广播版，占位符：老人姓名）</summary>
        public const string EmergencyRequestNeighborContentTemplate = "{0}发起紧急求助，您是附近邻居，请帮忙！";

        /// <summary>邻居正在赶来内容模板（占位符：邻居姓名）</summary>
        public const string HelperComingContentTemplate = "邻居{0}已接受您的求助，正在赶来！";

        /// <summary>邻居已响应紧急呼叫内容模板（占位符：邻居姓名、老人姓名）</summary>
        public const string HelperRespondedContentTemplate = "邻居{0}已响应{1}的紧急呼叫";

        /// <summary>求助已被接受内容模板（占位符：老人姓名、邻居姓名）</summary>
        public const string RequestAcceptedContentTemplate = "{0}的紧急求助已被{1}接受";

        /// <summary>求助已取消内容模板（占位符：老人姓名）</summary>
        public const string RequestCancelledContentTemplate = "{0}的紧急求助已被取消";
    }

    /// <summary>位置相关通知</summary>
    public static class Location
    {
        /// <summary>安全区域预警标题</summary>
        public const string GeoFenceAlertTitle = "安全区域预警";

        /// <summary>围栏越界内容模板（占位符：老人姓名、距离描述）</summary>
        public const string GeoFenceAlertContentTemplate = "{0}已离开安全区域，当前位置距离安全中心{1}，请及时关注。";
    }

    /// <summary>健康相关通知</summary>
    public static class Health
    {
        /// <summary>健康异常预警标题</summary>
        public const string AnomalyAlertTitle = "健康异常预警";

        /// <summary>健康异常预警内容模板（占位符：老人姓名、类型标签、数值展示、预警消息）</summary>
        public const string AnomalyAlertContentTemplate = "{0}的{1}数据异常：{2}。{3}请及时关注。";
    }

    /// <summary>自动救援相关通知</summary>
    public static class AutoRescue
    {
        /// <summary>紧急确认请求标题</summary>
        public const string UrgentConfirmTitle = "紧急：请尽快确认老人安全";

        /// <summary>已自动通知邻里圈标题</summary>
        public const string AutoNotifiedTitle = "已自动通知邻里圈";

        /// <summary>围栏越界触发描述</summary>
        public const string GeoFenceBreachText = "走出安全区域";

        /// <summary>心跳超时触发描述</summary>
        public const string HeartbeatTimeoutText = "设备长时间无响应";

        /// <summary>紧急确认内容模板（占位符：老人姓名、触发描述、等待分钟数）</summary>
        public const string UrgentConfirmContentTemplate = "{0}{1}，请在 {2} 分钟内确认安全，否则将自动通知邻里圈求助。";

        /// <summary>已自动通知邻里圈内容模板（占位符：老人姓名）</summary>
        public const string AutoNotifiedContentTemplate = "{0}的告警您未及时确认，已自动通知邻里圈求助。";
    }

    /// <summary>紧急呼叫相关通知</summary>
    public static class Emergency
    {
        /// <summary>紧急呼叫标题</summary>
        public const string CallTitle = "紧急呼叫";

        /// <summary>紧急呼叫提醒标题</summary>
        public const string CallReminderTitle = "紧急呼叫仍未响应";

        /// <summary>紧急呼叫内容模板（占位符：老人姓名）</summary>
        public const string CallContentTemplate = "{0}发起了紧急呼叫，请尽快处理！";

        /// <summary>紧急呼叫提醒内容模板（占位符：老人姓名）</summary>
        public const string CallReminderContentTemplate = "{0}的紧急呼叫已超过3分钟未得到响应，请尽快处理！";

        /// <summary>SMS 紧急呼叫内容模板（占位符：老人姓名）</summary>
        public const string SmsCallContentTemplate = "【紧急呼叫】{0}发起了紧急呼叫，请立即查看并处理！";

        /// <summary>SMS 紧急提醒内容模板（占位符：老人姓名）</summary>
        public const string SmsReminderContentTemplate = "【紧急提醒】{0}的紧急呼叫已超过3分钟未响应，请尽快处理！";

        /// <summary>紧急呼叫已响应通知标题（发送给老人）</summary>
        public const string CallRespondedTitle = "呼叫已响应";

        /// <summary>紧急呼叫已响应内容模板（占位符：响应人姓名）</summary>
        public const string CallRespondedContentTemplate = "您的家人{0}已响应您的紧急呼叫，正在处理中";
    }

    /// <summary>用药提醒相关通知</summary>
    public static class Medication
    {
        /// <summary>用药提醒标题</summary>
        public const string ReminderTitle = "用药提醒";

        /// <summary>用药再次提醒标题</summary>
        public const string ReminderSecondaryTitle = "用药提醒（再次提醒）";

        /// <summary>用药提醒内容模板（占位符：药品名称、剂量）</summary>
        public const string ReminderContentTemplate = "请按时服用 {0}，剂量：{1}";

        /// <summary>用药再次提醒内容模板（占位符：药品名称、剂量）</summary>
        public const string ReminderSecondaryContentTemplate = "您还未服用 {0}（{1}），请尽快服药。";

        /// <summary>老人未服药通知子女标题</summary>
        public const string MissedTitle = "老人未服药提醒";

        /// <summary>老人未服药内容模板（占位符：老人姓名、时间、药品名称、剂量、延迟分钟数）</summary>
        public const string MissedContentTemplate = "{0} 在 {1} 的 {2}（{3}）已超过 {4} 分钟未确认服药，请电话确认。";

        /// <summary>子女端用药提醒标题</summary>
        public const string FamilyReminderTitle = "老人用药提醒";

        /// <summary>子女端用药提醒内容模板（占位符：老人姓名、药品名称）</summary>
        public const string FamilyReminderContentTemplate = "{0} 应服用 {1}";
    }

    /// <summary>心跳监控相关通知</summary>
    public static class Heartbeat
    {
        /// <summary>老人离线告警标题</summary>
        public const string OfflineTitle = "老人离线告警";

        /// <summary>老人离线告警内容模板（占位符：老人姓名、离线分钟数）</summary>
        public const string OfflineContentTemplate = "{0} 已超过 {1} 分钟未响应心跳，请及时确认是否安全。";
    }

    /// <summary>默认通知标题（SignalR 投递时无 Title 字段的兜底值）</summary>
    public const string DefaultTitle = "通知";
}

/// <summary>
/// 健康预警消息常量
/// 集中管理 HealthAlertService 中的预警消息，确保表述一致
/// </summary>
public static class HealthAlertMessages
{
    /// <summary>血压预警</summary>
    public static class BloodPressure
    {
        public const string CriticalHigh = "血压严重偏高，建议立即就医！";
        public const string ModerateHigh = "血压偏高（中度高血压），建议尽快就医检查。";
        public const string MildHigh = "血压偏高，建议注意休息并监测。";
        public const string CriticalLow = "血压严重偏低，建议立即就医！";
        public const string MildLow = "血压偏低，建议注意营养补充。";
    }

    /// <summary>血糖预警</summary>
    public static class BloodSugar
    {
        public const string CriticalHigh = "血糖严重偏高（可能为糖尿病），建议立即就医！";
        public const string ModerateHigh = "血糖偏高，建议尽快就医检查。";
        public const string MildHigh = "血糖偏高，建议注意饮食控制。";
        public const string CriticalLow = "血糖严重偏低（低血糖危险），建议立即补充糖分！";
        public const string MildLow = "血糖偏低，建议适当补充糖分。";
    }

    /// <summary>心率预警</summary>
    public static class HeartRate
    {
        public const string CriticalHigh = "心率过快，建议立即就医检查！";
        public const string MildHigh = "心率偏快，建议注意休息放松。";
        public const string CriticalLow = "心率过慢，建议立即就医检查！";
        public const string MildLow = "心率偏慢，建议关注身体状况。";
    }

    /// <summary>体温预警</summary>
    public static class Temperature
    {
        public const string CriticalHigh = "高烧，建议立即就医！";
        public const string ModerateHigh = "发烧，建议及时就医检查。";
        public const string MildHigh = "低烧，建议注意休息观察。";
        public const string CriticalLow = "体温过低，建议立即就医！";
        public const string MildLow = "体温偏低，建议注意保暖。";
    }

    /// <summary>异常检测建议（HealthAnomalyDetector 使用）</summary>
    public static class AnomalySuggestions
    {
        /// <summary>峰值异常建议</summary>
        public static class Spike
        {
            public const string BloodPressureHigh = "建议安静休息10分钟后复测，若仍高于180/110请及时就医";
            public const string BloodPressureLow = "建议平躺休息、适量饮水，若伴有头晕请及时就医";
            public const string BloodSugarHigh = "建议1小时后复测，避免进食甜食，若持续高于15请就医";
            public const string BloodSugarLow = "建议立即补充糖分（如糖果、果汁），若持续低于3请就医";
            public const string HeartRateHigh = "建议静坐休息，避免咖啡因和剧烈运动，若持续高于150请就医";
            public const string HeartRateLow = "建议缓慢起身、避免突然体位变化，若持续低于40请就医";
            public const string TemperatureHigh = "建议多饮水、物理降温，若超过39°C请就医";
            public const string TemperatureLow = "建议保暖、喝温水，若持续低于35°C请就医";
        }

        /// <summary>持续偏高建议</summary>
        public static class ContinuousHigh
        {
            public const string BloodPressure = "血压已连续偏高数日，建议减少盐分摄入、保持规律作息，若情况持续请就诊";
            public const string BloodSugar = "血糖已连续偏高数日，建议控制碳水摄入、适当运动，若情况持续请就诊";
            public const string HeartRate = "心率已连续偏高，建议减少咖啡因摄入、保证充足睡眠，若情况持续请就诊";
            public const string Temperature = "体温已连续偏高，建议多饮水、注意休息，若情况持续请就诊";
        }

        /// <summary>持续偏低建议</summary>
        public static class ContinuousLow
        {
            public const string BloodPressure = "血压已连续偏低，建议适量增加盐分和水分摄入，起身时动作放缓";
            public const string BloodSugar = "血糖已连续偏低，建议规律进餐、适当加餐，避免空腹运动";
            public const string HeartRate = "心率已连续偏低，建议避免过度劳累，起身时注意防止眩晕";
            public const string Temperature = "体温已连续偏低，建议注意保暖、适当增加衣物";
        }

        /// <summary>波动性异常建议</summary>
        public static class Volatility
        {
            public const string BloodPressure = "近期血压波动较大，建议定时测量（早晚各一次）、记录饮食和用药情况";
            public const string BloodSugar = "近期血糖波动较大，建议固定时间测量、注意饮食规律";
            public const string HeartRate = "近期心率波动较大，建议记录活动与心率的关系、避免过度劳累";
        }

        /// <summary>通用建议</summary>
        public const string General = "建议关注身体状况，如有不适请及时就医";
        public const string GeneralHigh = "指标已连续偏高，建议关注身体状况，必要时就医";
        public const string GeneralLow = "指标已连续偏低，建议关注身体状况，保持规律作息";
        public const string GeneralVolatility = "近期数据波动较大，建议规律测量并记录生活情况，必要时咨询医生";
    }

    /// <summary>
    /// 严重度关键词（GetAlertLevel 中用于判断预警等级）
    /// </summary>
    public static class SeverityKeywords
    {
        /// <summary>立即就医关键词</summary>
        public const string ImmediateTreatment = "立即就医";

        /// <summary>严重关键词</summary>
        public const string Severe = "严重";

        /// <summary>尽快就医关键词</summary>
        public const string PromptTreatment = "尽快就医";

        /// <summary>及时就医关键词</summary>
        public const string TimelyTreatment = "及时就医";
    }

    /// <summary>
    /// 异常检测消息模板（HealthAnomalyDetector 使用）
    /// </summary>
    public static class AnomalyDetection
    {
        /// <summary>积极反馈 - 极佳（占位符：健康标签）</summary>
        public const string FeedbackExcellentTemplate = "过去一周{0}控制极佳，波动极小，请继续保持良好的生活习惯！";

        /// <summary>积极反馈 - 良好（占位符：健康标签）</summary>
        public const string FeedbackGoodTemplate = "过去一周{0}控制良好，数据波动在正常范围内。";

        /// <summary>积极反馈 - 平稳（占位符：健康标签）</summary>
        public const string FeedbackStableTemplate = "过去一周{0}数据保持平稳，一切正常。";

        /// <summary>峰值突增描述模板（占位符：健康类型、数值、偏离百分比）</summary>
        public const string SpikeUpTemplate = "{0}值突增至{1}，超过基线{2}%";

        /// <summary>峰值突降描述模板（占位符：健康类型、数值、偏离百分比）</summary>
        public const string SpikeDownTemplate = "{0}值突降至{1}，低于基线{2}%";

        /// <summary>持续偏高描述模板（占位符：健康类型、天数、阈值百分比）</summary>
        public const string ContinuousHighTemplate = "{0}连续{1}天高于基线{2}%以上";

        /// <summary>持续偏低描述模板（占位符：健康类型、天数、阈值百分比）</summary>
        public const string ContinuousLowTemplate = "{0}连续{1}天低于基线{2}%以上";

        /// <summary>波动性增大描述模板（占位符：基线天数、健康类型、倍数）</summary>
        public const string VolatilityTemplate = "最近{0}天{1}波动性增大，标准差较历史升高{2}倍";
    }
}
