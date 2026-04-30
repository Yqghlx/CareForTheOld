import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  /// 主色调 - 温暖的橙色调，适合老人应用
  static const Color primaryColor = Color(0xFFE86B4A);
  static const Color primaryLight = Color(0xFFF5A68A);
  static const Color primaryDark = Color(0xFFC94E32);

  /// 辅助色
  static const Color secondaryColor = Color(0xFF4A90E2);
  static const Color successColor = Color(0xFF52C41A);
  static const Color warningColor = Color(0xFFFAAD14);
  static const Color errorColor = Color(0xFFFF4D4F);

  /// 辅助色变体（对应 MaterialColor shade）
  static const Color successLight = Color(0xFFA5D6A7);  // ~green.shade200
  static const Color successDark = Color(0xFF388E3C);   // ~green.shade700
  static const Color successMedium = Color(0xFF66BB6A); // ~green.shade400
  static const Color warningLight = Color(0xFFFFCC80);  // ~orange.shade200
  static const Color warningDark = Color(0xFFF57C00);   // ~orange.shade700
  static const Color errorLight = Color(0xFFFFCDD2);    // ~red.shade100
  static const Color errorMedium = Color(0xFFEF9A9A);   // ~red.shade200
  static const Color errorDark = Color(0xFFD32F2F);     // ~red.shade700
  static const Color errorAccent = Color(0xFFFF5252);   // ~redAccent
  static const Color infoBlue = Color(0xFF2196F3);      // ~blue.shade500
  static const Color infoBlueLight = Color(0xFFBBDEFB); // ~blue.shade100
  static const Color infoBlueDark = Color(0xFF1976D2);  // ~blue.shade700

  /// 语义色（健康数据图表、枚举标签等场景使用）
  static const Color purpleColor = Color(0xFF9C27B0);    // ~purple.shade500
  static const Color tealColor = Color(0xFF009688);      // ~teal.shade500
  static const Color cyanColor = Color(0xFF00BCD4);      // ~cyan.shade500
  static const Color deepOrangeColor = Color(0xFFFF5722); // ~deepOrange.shade500
  static const Color blueGrey800 = Color(0xFF37474F);    // ~blueGrey.shade800
  static const Color amberColor = Color(0xFFFFC107);      // ~amber.shade500（评分星星、奖牌金）
  static const Color brownColor = Color(0xFF795548);      // ~brown.shade500（奖牌铜）

  /// 背景色
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;

  /// 文字色（textHint 满足 WCAG AAA 对比度标准 7:1）
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF616161);

  /// 灰度色（统一项目中的灰色系使用）
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);

  /// 透明色（替代 Colors.transparent）
  static const Color transparentColor = Colors.transparent;

  /// 阴影色（5% 黑，用于卡片 BoxShadow）
  static const Color shadowLight = Color(0x0D000000);
  /// 遮罩色（40% 黑，用于上传遮罩等场景）
  static const Color overlayDark = Color(0x66000000);

  /// 预定义文本样式（高频组合，统一管理）
  static const TextStyle textTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
  static const TextStyle textSubtitle = TextStyle(fontSize: 14, color: grey600);
  static const TextStyle textCaption = TextStyle(fontSize: 12, color: grey500);
  static const TextStyle textBody = TextStyle(fontSize: 14);
  static const TextStyle textCardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const TextStyle textLargeTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
  static const TextStyle textHeading = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
  static const TextStyle textBody18 = TextStyle(fontSize: 18);
  static const TextStyle textBody16 = TextStyle(fontSize: 16);
  static const TextStyle textBold = TextStyle(fontWeight: FontWeight.bold);
  static const TextStyle textWhite = TextStyle(color: Color(0xFFFFFFFF));
  static const TextStyle textWhite14 = TextStyle(fontSize: 14, color: Color(0xFFFFFFFF));
  static const TextStyle textWhite18W600 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF));
  static const TextStyle textSecondary16 = TextStyle(fontSize: 16, color: grey600);
  static const TextStyle textSecondary14 = TextStyle(fontSize: 14, color: grey600);
  static const TextStyle textCaptionDark = TextStyle(fontSize: 12, color: grey600);
  static const TextStyle textAxisLabel = TextStyle(fontSize: 14, color: grey800);
  static const TextStyle textError = TextStyle(color: errorColor);
  static const TextStyle textCaptionSmall = TextStyle(fontSize: 13);
  static const TextStyle textCaption13Grey600 = TextStyle(fontSize: 13, color: grey600);
  static const TextStyle textCaption13Grey700 = TextStyle(fontSize: 13, color: grey700);
  static const TextStyle textGrey = TextStyle(color: grey600);
  static const TextStyle textGreyLight = TextStyle(color: grey500);
  static const TextStyle textLogoTitle = TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryColor);
  static const TextStyle textLink14 = TextStyle(fontSize: 14, color: primaryColor);
  static const TextStyle textError14 = TextStyle(fontSize: 14, color: errorColor);
  static const TextStyle textErrorAlpha12 = TextStyle(fontSize: 12, color: Color(0x99FF4D4F));
  static const TextStyle textSectionTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);

  // 成功色系
  static const TextStyle textSuccess12 = TextStyle(fontSize: 12, color: successColor);
  static const TextStyle textSuccessDark14 = TextStyle(fontSize: 14, color: successDark);
  static const TextStyle textSuccessMedium12 = TextStyle(fontSize: 12, color: successMedium);

  // 警告色系
  static const TextStyle textWarningDark16 = TextStyle(fontSize: 16, color: warningDark);
  static const TextStyle textWarning16W600 = TextStyle(fontSize: 16, color: warningColor, fontWeight: FontWeight.w600);
  static const TextStyle textWarningDark11 = TextStyle(fontSize: 11, color: warningDark);

  // 信息色系
  static const TextStyle textInfoDark13 = TextStyle(fontSize: 13, color: infoBlueDark);

  // 灰度小字号
  static const TextStyle textGrey800_16 = TextStyle(fontSize: 16, color: grey800);
  static const TextStyle textGrey700_12 = TextStyle(fontSize: 12, color: grey700);
  static const TextStyle textSmall11Grey = TextStyle(fontSize: 11, color: grey500);
  static const TextStyle textEmptyTitle = TextStyle(fontSize: 18, color: grey500);
  static const TextStyle textEmptySubtitle = TextStyle(fontSize: 14, color: grey500);

  /// 渐变配置
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// 登录页渐变背景（暖白 → 纯白）
  static const LinearGradient warmBackgroundGradient = LinearGradient(
    colors: [Color(0xFFFFF5F0), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// ElevatedButton 样式：主色背景 + 圆角
  /// ElevatedButton 样式：主色背景 + 圆角
  static final ButtonStyle elevatedPrimaryStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    shape: RoundedRectangleBorder(borderRadius: radiusS),
  );

  /// 通用 OutlinedButton 样式工厂：前景色与边框同色
  static ButtonStyle outlinedColorStyle(Color color) => OutlinedButton.styleFrom(
    foregroundColor: color,
    side: BorderSide(color: color),
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFE86B4A), Color(0xFFFF9A6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 卡片圆角
  static const double cardRadius = 16.0;
  static const double cardRadiusLarge = 20.0;

  /// 图标尺寸常量
  static const double iconSizeSm = 18.0;
  static const double iconSizeMd = 20.0;
  static const double iconSizeLg = 24.0;
  static const double iconSize2xl = 28.0;
  static const double iconSizeXl = 32.0;
  static const double iconSizeXxl = 48.0;
  static const double iconSizeHuge = 64.0;

  /// 小型加载指示器（按钮内使用）
  static const Widget smallLoadingIndicator = SizedBox(
    width: iconSizeLg,
    height: iconSizeLg,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  /// 按钮高度
  static const double buttonHeight = 56.0;

  /// 卡片阴影
  static const double cardElevation = 4.0;
  static const double cardElevationLow = 2.0;
  static const double cardElevationHigh = 6.0;

  /// 按钮圆角
  static const double buttonRadius = 12.0;

  /// 预定义 BorderRadius 常量（统一项目中圆角使用）
  static const BorderRadius radius4 = BorderRadius.all(Radius.circular(4));
  static const BorderRadius radiusXS = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radius6 = BorderRadius.all(Radius.circular(6));
  static const BorderRadius radiusS = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusM = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusL = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radius10 = BorderRadius.all(Radius.circular(10));
  static const BorderRadius radiusXL = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusTopXL = BorderRadius.vertical(top: Radius.circular(20));
  static const BorderRadius radius2XL = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radius3XL = BorderRadius.all(Radius.circular(32));
  static const BorderRadius radiusZero = BorderRadius.zero;

  /// 统一间距常量
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacing20Lg = 20.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  /// 预定义 EdgeInsets 常量（高频组合，统一管理）
  static const EdgeInsets paddingAll4 = EdgeInsets.all(4);
  static const EdgeInsets paddingAll6 = EdgeInsets.all(6);
  static const EdgeInsets paddingAll8 = EdgeInsets.all(8);
  static const EdgeInsets paddingAll12 = EdgeInsets.all(12);
  static const EdgeInsets paddingAll16 = EdgeInsets.all(16);
  static const EdgeInsets paddingAll20 = EdgeInsets.all(20);
  static const EdgeInsets paddingAll24 = EdgeInsets.all(24);
  static const EdgeInsets paddingH16V8 = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets paddingH16V12 = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets paddingH8V4 = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const EdgeInsets paddingH8V2 = EdgeInsets.symmetric(horizontal: 8, vertical: 2);
  static const EdgeInsets paddingH12V4 = EdgeInsets.symmetric(horizontal: 12, vertical: 4);
  static const EdgeInsets paddingH12V8 = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const EdgeInsets paddingH16V10 = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  static const EdgeInsets paddingH12V6 = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  static const EdgeInsets paddingH8V3 = EdgeInsets.symmetric(horizontal: 8, vertical: 3);
  static const EdgeInsets paddingH32 = EdgeInsets.symmetric(horizontal: 32);
  static const EdgeInsets marginBottom8 = EdgeInsets.only(bottom: 8);
  static const EdgeInsets marginBottom12 = EdgeInsets.only(bottom: 12);
  static const EdgeInsets marginTop8 = EdgeInsets.only(top: 8);
  static const EdgeInsets marginTop12 = EdgeInsets.only(top: 12);
  static const EdgeInsets paddingAll14 = EdgeInsets.all(14);
  static const EdgeInsets marginBottom16 = EdgeInsets.only(bottom: 16);
  static const EdgeInsets marginBottom4 = EdgeInsets.only(bottom: 4);
  static const EdgeInsets marginBottom10 = EdgeInsets.only(bottom: 10);
  static const EdgeInsets marginTop4 = EdgeInsets.only(top: 4);
  static const EdgeInsets marginTop16 = EdgeInsets.only(top: 16);
  static const EdgeInsets paddingTop16 = EdgeInsets.only(top: 16);
  static const EdgeInsets paddingAll10 = EdgeInsets.all(10);
  static const EdgeInsets paddingAll32 = EdgeInsets.all(32);
  static const EdgeInsets paddingV8 = EdgeInsets.symmetric(vertical: 8);
  static const EdgeInsets paddingV10 = EdgeInsets.symmetric(vertical: 10);
  static const EdgeInsets paddingV12 = EdgeInsets.symmetric(vertical: 12);
  static const EdgeInsets paddingV4 = EdgeInsets.symmetric(vertical: 4);
  static const EdgeInsets paddingV14 = EdgeInsets.symmetric(vertical: 14);
  static const EdgeInsets paddingV16 = EdgeInsets.symmetric(vertical: 16);
  static const EdgeInsets paddingH8 = EdgeInsets.symmetric(horizontal: 8);
  static const EdgeInsets paddingH24V12 = EdgeInsets.symmetric(horizontal: 24, vertical: 12);

  /// 常用垂直间距组件
  static const SizedBox spacer24 = SizedBox(height: 24);
  static const SizedBox spacer32 = SizedBox(height: 32);
  static const SizedBox spacer48 = SizedBox(height: 48);
  static const SizedBox spacer20 = SizedBox(height: 20);
  static const SizedBox spacer16 = SizedBox(height: 16);
  static const SizedBox spacer12 = SizedBox(height: 12);
  static const SizedBox spacer10 = SizedBox(height: 10);
  static const SizedBox spacer8 = SizedBox(height: 8);
  static const SizedBox spacer6 = SizedBox(height: 6);
  static const SizedBox spacer4 = SizedBox(height: 4);
  static const SizedBox spacer2 = SizedBox(height: 2);

  /// 常用水平间距组件
  static const SizedBox hSpacer20 = SizedBox(width: 20);
  static const SizedBox hSpacer16 = SizedBox(width: 16);
  static const SizedBox hSpacer12 = SizedBox(width: 12);
  static const SizedBox hSpacer8 = SizedBox(width: 8);
  static const SizedBox hSpacer4 = SizedBox(width: 4);

  /// 统一用户消息常量
  static const String msgLoadFailed = '加载失败，请重试';
  static const String msgOperationFailed = '操作失败，请稍后重试';
  static const String msgNetworkError = '网络连接失败，请检查网络设置';
  static const String msgOffline = '网络已断开，部分功能不可用';
  static const String msgSaveSuccess = '保存成功';
  static const String msgDeleteSuccess = '删除成功';

  // 通用按钮文案
  static const String msgCancel = '取消';
  static const String msgDelete = '删除';
  static const String msgConfirm = '确定';
  static const String msgSave = '保存';
  static const String msgEdit = '编辑';
  static const String msgCreate = '创建';
  static const String msgLogin = '登录';
  static const String msgConfirmDelete = '确认删除';

  // 应用名
  static const String appName = '关爱老人';

  // API 错误消息
  static const String msgForbidden = '权限不足，无法执行此操作';
  static const String msgNotFound = '请求的资源不存在';
  static const String msgServerError = '服务器繁忙，请稍后重试';
  static const String msgSessionExpired = '登录已过期，请重新登录';

  // 用药相关消息
  static const String msgMedicationTaken = '已标记为已服用';
  static const String msgMedicationSkipped = '已跳过本次用药';
  static const String msgNoPendingMedication = '当前没有待服用的药物';
  static const String msgVoiceNotAvailable = '语音识别不可用，请检查设备设置';
  static const String msgVoiceStartFailed = '语音识别启动失败，请手动操作';
  static const String msgVoiceCommandNotRecognized = '未能识别指令，请说"已服药"或"跳过"';
  static const String msgVoiceInputFailed = '语音识别启动失败，请手动输入';

  // 用药状态标签
  static const String labelMedPending = '待服用';
  static const String labelMedTaken = '已服用';
  static const String labelMedSkipped = '已跳过';

  // 紧急呼叫消息
  static const String msgEmergencyLongPress = '请长按按钮 2 秒发起紧急呼叫';
  static const String msgEmergencyCancelled = '已取消，请长按 2 秒发起呼叫';
  static const String msgEmergencySent = '紧急呼叫已发送，已通知家人和附近邻居';
  static const String msgEmergencyFailed = '呼叫失败，请直接拨打电话联系家人';
  static const String msgEmergencyLocationFailed = '紧急呼叫已发送，但无法获取定位，家人可能无法确定您的位置';

  // 健康录入消息
  static const String msgReportGenerated = '报告已生成，请选择分享方式';
  static const String msgRecordDeleted = '记录已删除';
  static const String msgOcrSuccess = '识别成功，已自动填充数值';
  static const String msgOcrNoValue = '未能识别到有效数值，请手动输入';
  static const String msgOcrFailed = '文字识别失败，请重新拍照';
  static const String msgInvalidValue = '请输入有效的数值';
  static const String msgRecordSaved = '记录已保存';
  static const String msgAnomalyAnalyzing = '正在分析健康趋势...';
  static const String msgAnomalyLoadFailed = '异常检测加载失败，请重试';

  // 个人设置消息
  static const String msgNameUpdated = '姓名修改成功';
  static const String msgPasswordEmpty = '密码不能为空';
  static const String msgPasswordMismatch = '两次输入的新密码不一致';
  static const String msgPasswordChanged = '密码修改成功，请重新登录';
  static const String msgPasswordChangeFailed = '修改失败，请重试';
  static String msgModifyFailed(String error) => '修改失败: $error';
  static const String msgOldPasswordIncorrect = '旧密码不正确';
  static const String msgAvatarUpdated = '头像更新成功';
  static const String msgAvatarFailed = '头像上传失败，请重试';
  static const String msgPasswordStrengthStrong = '密码强度：强';
  static const String msgPasswordStrengthMedium = '密码强度：中';
  static const String msgPasswordStrengthWeak = '密码强度：弱';

  // 邻里互助消息
  static const String msgHelpAccepted = '已接受求助，请尽快前往帮助';
  static const String msgHelpAlreadyTaken = '该求助已被其他邻居接受';
  static const String msgRateSuccess = '评价成功，感谢您的反馈';

  // 邻里圈消息
  static const String msgInviteCodeHint = '请输入 6 位邀请码';
  static const String msgJoinSuccess = '加入成功';
  static const String msgCircleNameRequired = '请输入圈子名称';
  static const String msgCreateSuccess = '创建成功';
  static const String msgLeftCircle = '已退出';
  static const String msgInviteRefreshed = '邀请码已刷新';
  static const String msgNoCircleNearby = '附近没有找到邻里圈';

  // 紧急告警消息
  static const String msgMarkHandled = '已标记处理';
  static const String msgNoPhoneNumber = '无法获取老人电话号码';
  static const String msgCannotDial = '无法拨打电话，请手动拨打';

  // 页面标题与通用 UI 文案
  static const String msgHealthRecords = '健康记录';
  static const String msgHealthTrends = '健康趋势';
  static const String msgMedicationReminder = '用药提醒';
  static const String msgConfirmSkip = '确认跳过';
  static const String msgExportReport = '导出健康报告';
  static const String msgSelectDateRange = '选择报告时间范围：';
  static const String msgLoadingStats = '加载统计中...';
  static const String msgStatsLoadFailed = '统计加载失败';
  static const String msgRetry = '重试';

  // 页面标题
  static const String titleRegister = '注册账号';
  static const String titleNeighborHelp = '邻里互助';
  static const String titleHelpRating = '评价互助';
  static const String titleTrustRanking = '信任排行榜';
  static const String titleNotification = '通知中心';
  static const String titleNeighborCircle = '邻里圈';
  static const String titleSettings = '设置';
  static const String titleEmergencyCall = '紧急呼叫';
  static const String titleConfirmHandle = '确认处理';
  static const String titleCallHistory = '历史呼叫记录';
  static const String titleLocationView = '位置查看';
  static const String titleFamilyMember = '家庭成员';
  static const String titleApproveConfirm = '审批确认';
  static const String titleRejectApply = '拒绝申请';
  static const String titleRefreshInviteCode = '刷新邀请码';
  static const String titleRemoveMember = '移除成员';

  // 家庭成员消息
  static const String msgFamilyApproved = '已通过';
  static const String msgFamilyRejected = '已拒绝申请';
  static const String msgInviteCodeCopied = '邀请码已复制';
  static const String msgFamilyCreated = '创建成功！邀请码已生成';
  static const String msgFamilyCreateFailed = '创建失败';
  static const String msgInviteCodeRequired = '请输入6位邀请码并选择关系';
  static const String msgApplyFailed = '申请失败，请检查邀请码';
  static const String msgInvalidPhoneFormat = '请输入正确的手机号格式';
  static const String msgMemberAdded = '添加成功';
  static const String msgMemberAddFailed = '添加失败';
  static const String msgMemberRemoved = '已移除';
  static const String msgMemberRemoveFailed = '移除失败';
  static const String msgAddElderFirst = '请先添加老人到家庭成员';

  // 围栏消息
  static const String msgFenceDeleted = '安全区域已删除';
  static const String msgFenceSaved = '安全区域已保存';
  static const String msgFenceSaveFailed = '保存失败';
  static const String msgFenceEnabled = '安全区域已启用';
  static const String msgFenceDisabled = '安全区域已禁用';

  // 用药计划消息
  static const String msgMedicineNameRequired = '请填写药品名称和剂量';
  static const String msgPlanCreated = '用药计划创建成功';
  static const String msgPlanCreateFailed = '用药计划创建失败，请稍后重试';
  static const String msgPlanUpdated = '用药计划已更新';
  static String msgReminderEnabled(String name) => '已启用 $name 的用药提醒';
  static String msgReminderDisabled(String name) => '已停用 $name 的用药提醒';
  static String msgPlanDeleted(String name) => '已删除 $name 的用药计划';
  static const String msgMedicineNameInvalid = '请输入有效的药品名称（1-50字符）';
  static const String msgDosageInvalid = '请输入有效的剂量（1-30字符）';
  static const String msgReminderTimeRequired = '请至少添加一个提醒时间';
  static const String msgConfirmSkipMedicine = '确定跳过本次用药吗？';
  static String msgConfirmSkipWithName(String name) => '确定跳过 $name 本次用药吗？';

  // 定位消息
  static const String msgLocationServiceDisabled = '定位服务未开启，将使用默认位置';
  static const String msgLocationPermissionDenied = '定位权限被拒绝，将使用默认位置';
  static const String msgLocationPermissionPermanentlyDenied = '定位权限被永久拒绝，将使用默认位置';
  static const String msgLocationFailed = '获取位置失败，将使用默认位置';

  // 时间范围标签
  static const String labelRecent7Days = '最近7天';
  static const String labelRecent30Days = '最近30天';

  // 空状态提示文案
  static const String msgNoHealthRecord = '暂无健康记录';
  static const String msgNoHistoryRecord = '暂无历史记录';
  static const String msgNoStats = '暂无统计数据';
  static const String msgNoNotification = '暂无通知';
  static const String msgNoPendingHelp = '暂无待响应的求助';
  static const String msgNoHelpRecord = '暂无互助记录';
  static const String msgNoTrustData = '暂无信任评分数据';
  static const String msgNoMemberInfo = '暂无成员信息';
  static const String msgNoLocationData = '暂无位置数据，请等待老人上报位置';
  static const String msgNoLocationRecord = '暂无位置记录';
  static const String msgNoFamilyMember = '暂无家庭成员';
  static const String msgNoElderConcern = '暂无关注的老人';
  static const String msgNoMedicationLog = '暂无用药记录';
  static const String msgNoPendingEmergency = '暂无待处理的紧急呼叫';
  static const String msgNoCallRecord = '暂无呼叫记录';

  // 首页区块标题
  static const String titleTodayHealth = '今日健康';
  static const String titleTodayMedication = '今日用药';
  static const String labelViewDetails = '查看详情';
  static const String labelGoRecord = '去记录';
  static const String msgNoMedicationPlanToday = '今日暂无用药计划';
  static const String titleCallSent = '呼叫已发送';
  static const String msgCallSentDetail = '您的紧急呼叫已成功发送，已通知家人和附近邻居。';
  static const String labelPendingCount = '项待服';

  // 设置页面标题
  static const String titleChangeName = '修改姓名';
  static const String titleChangePassword = '修改密码';

  // 表单标签
  static const String labelPhone = '手机号';
  static const String labelPassword = '密码';
  static const String labelRealName = '姓名';
  static const String labelInviteCode = '邀请码';
  static const String tooltipShowPassword = '显示密码';
  static const String tooltipHidePassword = '隐藏密码';

  // 健康录入表单标签
  static const String labelSystolic = '收缩压（mmHg）';
  static const String labelDiastolic = '舒张压（mmHg）';
  static const String labelBloodSugarValue = '血糖值（mmol/L）';
  static const String labelHeartRateValue = '心率（次/分）';
  static const String labelTemperatureValue = '体温（°C）';
  static const String labelNoteOptional = '备注（可选）';

  // 密码修改表单标签
  static const String labelOldPassword = '旧密码';
  static const String labelNewPassword = '新密码';
  static const String labelConfirmPassword = '确认新密码';
  static const String helperPasswordRule = '至少8位，需包含字母和数字';

  // 常用 tooltip
  static const String tooltipSettings = '设置';
  static const String tooltipRefresh = '刷新';
  static const String tooltipExportReport = '导出报告';
  static const String tooltipViewTrend = '查看趋势';
  static const String tooltipVoiceConfirm = '语音确认服药';
  static const String tooltipCallHistory = '历史记录';
  static const String tooltipEmergencyCall = '紧急呼叫';

  // 通用按钮/操作标签
  static const String labelLogout = '退出登录';
  static const String labelLogoutAction = '退出';
  static const String labelApprove = '通过';
  static const String labelReject = '拒绝';
  static const String labelClose = '关闭';
  static const String labelAddMember = '添加成员';
  static const String labelCreate = '创建';
  static const String labelRefresh = '刷新';

  // 设置页面区域标题
  static const String titleAboutUs = '关于我们';
  static const String titleHelpFeedback = '帮助与反馈';
  static const String titleSetGeoFence = '设置安全区域';

  // 头像选择
  static const String labelChangeAvatar = '更换头像';
  static const String labelFromAlbum = '从相册选择';
  static const String labelTakePhoto = '拍照';

  // 用药计划表单
  static const String labelMedicineName = '药品名称';
  static const String labelFrequency = '用药频率';

  // 杂项
  static const String labelNoName = '未设置姓名';
  static const String tooltipRefreshCode = '刷新邀请码';

  // 健康状态标签
  static const String labelHigh = '偏高';
  static const String labelLow = '偏低';

  // 健康类型标签
  static const String labelBloodPressure = '血压';
  static const String labelBloodSugar = '血糖';
  static const String labelHeartRate = '心率';
  static const String labelTemperature = '体温';

  // 默认角色/称谓
  static const String labelElder = '老人';
  static const String labelChild = '子女';
  static const String labelRelationOther = '其他';
  static const String labelSelectRole = '请选择您的身份:';

  // 登录/注册页面常量
  static const String msgAppTagline = '健康监测 · 用药提醒';
  static const String msgPasswordRequired = '请输入密码';
  static const String labelGoRegister = '去注册';
  static const String labelNoAccountRegister = '没有账号？点击注册';
  static const String labelHasAccountLogin = '已有账号？点击登录';
  static const String labelBirthDateOptional = '出生日期（选填）';
  static const String hintSelectBirthDate = '点击选择出生日期';
  static const String labelElderRoleDesc = '记录健康、查看用药提醒';
  static const String labelChildRoleDesc = '查看老人健康、管理用药计划';
  static const String labelRecentRecords = '最近记录';
  static const String hintStartRecording = '点击上方卡片开始记录';

  // 亲属称谓
  static const String labelGrandpaP = '爷爷';
  static const String labelGrandmaP = '奶奶';
  static const String labelGrandpaM = '外公';
  static const String labelGrandmaM = '外婆';
  static const String labelFather = '爸爸';
  static const String labelMother = '妈妈';
  static const String labelSon = '儿子';
  static const String labelDaughter = '女儿';

  // 邻里圈/互助/家庭/通知页面常量
  static const String labelCircleName = '圈子名称';
  static const String hintCircleName = '例如：阳光小区互助群';
  static const String labelCommentOptional = '评语（可选）';
  static const String hintComment = '分享您的互助体验...';
  static const String hintSearchNotification = '搜索通知...';
  static const String hintInviteCode6 = '输入 6 位数字邀请码';
  static const String labelFamilyGroupName = '家庭组名称';
  static const String hintFamilyGroupName = '如：张家';
  static const String labelInviteCode6 = '邀请码（6位数字）';
  static const String labelRelation = '您与创建者的关系';
  static const String labelRole = '角色';
  static const String labelNickname = '称呼';
  static const String labelDosage = '剂量（如：1片、10ml）';

  // 用药/设置/通知页面常量
  static const String titleTodayPlan = '今日用药计划';
  static const String titleNoPlanToday = '今日暂无用药计划';
  static const String subtitleNoPlanToday = '请让子女帮忙添加用药计划';
  static const String hintSearchEmpty = '尝试其他关键词搜索';
  static const String subtitleChangePassword = '更改登录密码';
  static const String subtitleLocationShare = '开启后子女可查看您的位置';
  static const String subtitleEmergencyAlwaysOn = '始终开启，保障安全';
  static const String subtitleHealthAlert = '健康异常预警、趋势提醒';
  static const String subtitleMedReminder = '用药时间到了提醒';
  static const String subtitleNeighborMessage = '邻里圈、邻里互助消息';
  static const String titleFunctionSettings = '功能设置';
  static const String titleNotificationSettings = '通知设置';
  static const String titleLocationReport = '位置上报';
  static const String titleEmergencyNotification = '紧急呼叫通知';
  static const String titleHealthNotification = '健康数据通知';
  static const String titleMedReminderNotification = '用药提醒通知';
  static const String titleNeighborNotification = '邻里动态通知';

  // 老人首页快速链接常量
  static const String titleRecordHealth = '记录健康';
  static const String subtitleRecordHealth = '血压、血糖、心率';
  static const String subtitleViewTodayMed = '查看今日用药';
  static const String subtitleFamilyMembers = '查看家人信息';
  static const String subtitleNeighborCircle = '附近邻居互助';
  static const String subtitleNeighborHelp = '求助与帮助邻居';
  static const String subtitlePersonalSettings = '个人信息设置';

  // 操作确认常量
  static const String titleConfirmRespond = '确认响应';
  static const String titleConfirmLeave = '确认退出';
  static const String msgAcceptHelp = '接受求助，前往帮忙';
  static const String tooltipCancelSearch = '取消搜索';
  static const String tooltipSearch = '搜索通知';

  // 健康记录页面常量
  static const String labelUseLastData = '使用上次数据';
  static const String hintNormalRangeBloodPressure = '正常范围: 收缩压 90-140 / 舒张压 60-90 mmHg';
  static const String hintNormalRangeBloodSugar = '正常范围: 空腹 3.9-6.1 mmol/L';
  static const String hintNormalRangeHeartRate = '正常范围: 60-100 次/分';
  static const String hintNormalRangeTemperature = '正常范围: 36.1-37.2 °C';

  // 子女端页面常量
  static const String titleDeleteGeoFence = '删除安全围栏';
  static const String subtitleHealthStatsEmpty = '老人记录健康数据后，这里会显示统计概览';
  static const String subtitleMedPlanEmpty = '点击下方按钮为老人创建用药计划';
  static const String subtitleHealthRecordsEmpty = '老人录入健康数据后，这里会显示记录列表';
  static const String titleNoMedRecord = '暂无用药记录';
  static const String subtitleNoMedRecord = '请为老人添加用药计划，以便跟踪用药情况';

  /// 业务常量
  /// 邻里圈搜索默认半径（米）
  static const double defaultNeighborSearchRadius = 2000.0;

  /// 图片配置
  static const double ocrImageMaxSize = 1024.0;
  static const int ocrImageQuality = 85;
  static const double avatarMaxSize = 512.0;
  static const int avatarImageQuality = 80;

  /// 老人端特殊配置 - 大字体、大按钮、更大圆角
  static ThemeData get elderTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    fontFamily: 'PingFangSC',
    scaffoldBackgroundColor: backgroundColor,
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadiusLarge),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      // 老人端使用更大的字体，适老化设计
      displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 22), // 老人端正文加大，适老化
      bodyMedium: TextStyle(fontSize: 18),
      bodySmall: TextStyle(fontSize: 16),
      labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 16),
      labelSmall: TextStyle(fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60), // 大按钮，适老化
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        textStyle: const TextStyle(fontSize: 18),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );

  /// 子女端主题 - 标准大小
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    fontFamily: 'PingFangSC',
    scaffoldBackgroundColor: backgroundColor,
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );

  // 常用时长常量
  static const Duration duration50ms = Duration(milliseconds: 50);
  static const Duration duration100ms = Duration(milliseconds: 100);
  static const Duration duration200ms = Duration(milliseconds: 200);
  static const Duration duration250ms = Duration(milliseconds: 250);
  static const Duration duration300ms = Duration(milliseconds: 300);
  static const Duration duration400ms = Duration(milliseconds: 400);
  static const Duration duration500ms = Duration(milliseconds: 500);
  static const Duration duration1s = Duration(seconds: 1);
  static const Duration duration1500ms = Duration(milliseconds: 1500);
  static const Duration duration2s = Duration(seconds: 2);
  static const Duration duration3s = Duration(seconds: 3);
  static const Duration duration4s = Duration(seconds: 4);
  static const Duration duration5s = Duration(seconds: 5);
  static const Duration duration10s = Duration(seconds: 10);
  static const Duration duration15s = Duration(seconds: 15);
  static const Duration duration30s = Duration(seconds: 30);
  static const Duration duration60s = Duration(seconds: 60);
  static const Duration duration5min = Duration(minutes: 5);

  /// 无边框 InputDecoration（配合 decorationInput 容器使用）
  /// 适用于内嵌在灰色背景容器中的纯文本/下拉输入框
  static InputDecoration inputDecorationPlain(String? labelText, {String? hintText}) =>
      InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: InputBorder.none,
        contentPadding: paddingH16V12,
      );

  /// 无边框 InputDecoration — 下拉框专用（较小垂直内边距）
  static InputDecoration inputDecorationDropdown(String? labelText) =>
      InputDecoration(
        labelText: labelText,
        border: InputBorder.none,
        contentPadding: paddingH16V8,
      );

  /// 预设 BoxDecoration — 表单输入区域背景（grey50 + radiusS）
  static const BoxDecoration decorationInput = BoxDecoration(
    color: grey50,
    borderRadius: radiusS,
  );

  /// 预设 BoxDecoration — 卡片/区域浅灰背景（grey100 + radiusL）
  static const BoxDecoration decorationCardLight = BoxDecoration(
    color: grey100,
    borderRadius: radiusL,
  );

  /// 预设 BoxDecoration — 图标圆形背景（primaryColor 15% + circle）
  static BoxDecoration decorationIconBg(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.15),
    shape: BoxShape.circle,
  );
}