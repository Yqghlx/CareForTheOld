import '../../../core/router/route_paths.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../core/constants/pref_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validators/form_validators.dart';
import '../providers/user_provider.dart';
import '../providers/notification_record_provider.dart';
import '../../elder/providers/health_provider.dart';
import '../../elder/providers/medication_provider.dart';
import '../../elder/services/location_reporter_service.dart';
import '../../shared/providers/emergency_provider.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _locationEnabled = true;
  bool _isLoadingLocation = true;
  String _appVersion = '';

  // 通知偏好
  bool _notifyHealth = true;
  bool _notifyMedication = true;
  bool _notifyNeighbor = true;
  bool _isLoadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadLocationSetting();
    _loadAppVersion();
    _loadNotificationPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).loadUser();
    });
  }

  /// 构建头像组件（有 URL 时显示网络图片，否则显示默认图标）
  Widget _buildAvatar(String? avatarUrl, double iconSize) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        memCacheWidth: 256,
        memCacheHeight: 256,
        maxWidthDiskCache: 512,
        maxHeightDiskCache: 512,
        errorWidget: (_, __, ___) => Icon(Icons.person, size: iconSize, color: AppTheme.cardColor),
      );
    }
    return Icon(Icons.person, size: iconSize, color: AppTheme.cardColor);
  }

  /// 加载定位设置
  Future<void> _loadLocationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _locationEnabled = prefs.getBool(PrefKeys.locationEnabled) ?? true;
      _isLoadingLocation = false;
    });
  }

  /// 加载应用版本信息
  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = '${info.version} (${info.buildNumber})');
  }

  /// 加载通知偏好设置
  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifyHealth = prefs.getBool(PrefKeys.notifyHealth) ?? true;
      _notifyMedication = prefs.getBool(PrefKeys.notifyMedication) ?? true;
      _notifyNeighbor = prefs.getBool(PrefKeys.notifyNeighbor) ?? true;
      _isLoadingPrefs = false;
    });
  }

  /// 保存通知偏好
  Future<void> _saveNotificationPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// 保存定位设置并实际控制位置上报服务
  Future<void> _saveLocationSetting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.locationEnabled, enabled);
    if (!mounted) return;
    setState(() => _locationEnabled = enabled);

    // 根据开关状态启动或停止位置上报服务
    final reporter = ref.read(locationReporterServiceProvider);
    if (enabled) {
      await reporter.start();
    } else {
      reporter.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userState = ref.watch(userProvider);
    final isElder = authState.isElder;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTheme.titleSettings),
      ),
      body: SingleChildScrollView(
        padding: AppTheme.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息卡片
            GradientCard(
              gradient: AppTheme.warmGradient,
              child: Padding(
                padding: AppTheme.paddingAll20,
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor.withValues(alpha: 0.2),
                        borderRadius: AppTheme.radiusL,
                      ),
                      child: ClipRRect(
                        borderRadius: AppTheme.radiusL,
                        child: _buildAvatar(
                          userState.user?.avatarUrl ?? authState.user?.avatarUrl,
                          40,
                        ),
                      ),
                    ),
                    AppTheme.hSpacer16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userState.user?.realName ?? authState.user?.realName ?? '用户',
                            style: AppTheme.textLargeTitle.copyWith(
                              color: AppTheme.cardColor,
                            ),
                          ),
                          AppTheme.spacer4,
                          Text(
                            userState.user?.phoneNumber ?? authState.user?.phoneNumber ?? '',
                            style: AppTheme.textWhite14.copyWith(
                              color: AppTheme.cardColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppTheme.spacer24,

            // 个人信息
            const Text(
              '个人信息',
              style: AppTheme.textTitle,
            ),
            AppTheme.spacer12,
            Card(
              elevation: AppTheme.cardElevationLow,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusL,
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: Icons.person_outline,
                    title: AppTheme.titleChangeName,
                    subtitle: userState.user?.realName ?? authState.user?.realName ?? '未设置',
                    onTap: () => _showEditNameDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    icon: Icons.lock_outline,
                    title: AppTheme.titleChangePassword,
                    subtitle: '更改登录密码',
                    onTap: () => _showChangePasswordDialog(),
                  ),
                ],
              ),
            ),
            AppTheme.spacer24,

            // 功能设置（老人端显示定位开关）
            if (isElder) ...[
              const Text(
                '功能设置',
                style: AppTheme.textTitle,
              ),
              AppTheme.spacer12,
              Card(
                elevation: AppTheme.cardElevationLow,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.radiusL,
                ),
                child: _buildSettingItem(
                  icon: Icons.location_on,
                  title: '位置上报',
                  subtitle: '开启后子女可查看您的位置',
                  trailing: _isLoadingLocation
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _locationEnabled,
                          onChanged: (value) => _saveLocationSetting(value),
                          activeTrackColor: AppTheme.primaryColor,
                          activeThumbColor: AppTheme.primaryColor,
                        ),
                ),
              ),
              AppTheme.spacer24,
            ],

            // 通知设置
            const Text(
              '通知设置',
              style: AppTheme.textTitle,
            ),
            AppTheme.spacer12,
            Card(
              elevation: AppTheme.cardElevationLow,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusL,
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: Icons.emergency,
                    title: '紧急呼叫通知',
                    subtitle: '始终开启，保障安全',
                    trailing: const Icon(Icons.lock, color: AppTheme.grey400, size: AppTheme.iconSizeMd),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    icon: Icons.favorite_outline,
                    title: '健康数据通知',
                    subtitle: '健康异常预警、趋势提醒',
                    trailing: _isLoadingPrefs
                        ? AppTheme.smallLoadingIndicator
                        : Switch(
                            value: _notifyHealth,
                            onChanged: (v) {
                              setState(() => _notifyHealth = v);
                              _saveNotificationPref(PrefKeys.notifyHealth, v);
                            },
                            activeTrackColor: AppTheme.primaryColor,
                            activeThumbColor: AppTheme.primaryColor,
                          ),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    icon: Icons.medication_outlined,
                    title: '用药提醒通知',
                    subtitle: '用药时间到了提醒',
                    trailing: _isLoadingPrefs
                        ? AppTheme.smallLoadingIndicator
                        : Switch(
                            value: _notifyMedication,
                            onChanged: (v) {
                              setState(() => _notifyMedication = v);
                              _saveNotificationPref(PrefKeys.notifyMedication, v);
                            },
                            activeTrackColor: AppTheme.primaryColor,
                            activeThumbColor: AppTheme.primaryColor,
                          ),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    icon: Icons.diversity_3_outlined,
                    title: '邻里动态通知',
                    subtitle: '邻里圈、邻里互助消息',
                    trailing: _isLoadingPrefs
                        ? AppTheme.smallLoadingIndicator
                        : Switch(
                            value: _notifyNeighbor,
                            onChanged: (v) {
                              setState(() => _notifyNeighbor = v);
                              _saveNotificationPref(PrefKeys.notifyNeighbor, v);
                            },
                            activeTrackColor: AppTheme.primaryColor,
                            activeThumbColor: AppTheme.primaryColor,
                          ),
                  ),
                ],
              ),
            ),
            AppTheme.spacer24,

            // 其他设置
            const Text(
              '其他',
              style: AppTheme.textTitle,
            ),
            AppTheme.spacer12,
            Card(
              elevation: AppTheme.cardElevationLow,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusL,
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: AppTheme.titleAboutUs,
                    subtitle: '${AppTheme.appName} App ${_appVersion.isNotEmpty ? "v$_appVersion" : ""}',
                    onTap: () => _showAboutDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    icon: Icons.help_outline,
                    title: AppTheme.titleHelpFeedback,
                    subtitle: '使用帮助、问题反馈',
                    onTap: () => _showHelpDialog(),
                  ),
                ],
              ),
            ),
            AppTheme.spacer32,

            // 退出登录按钮
            PrimaryButton(
              text: AppTheme.labelLogout,
              onPressed: () => _showLogoutDialog(),
              gradient: const LinearGradient(
                colors: [AppTheme.errorColor, AppTheme.errorAccent],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 设置项
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.radiusL,
      child: Padding(
        padding: AppTheme.paddingAll16,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.radiusS,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: AppTheme.iconSizeLg),
            ),
            AppTheme.hSpacer16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.textHeading,
                  ),
                  AppTheme.spacer2,
                  Text(
                    subtitle,
                    style: AppTheme.textSubtitle,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null && onTap != null)
              const Icon(Icons.chevron_right, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }

  /// 显示修改姓名对话框
  void _showEditNameDialog() {
    final authState = ref.read(authProvider);
    final currentName = authState.user?.realName ?? '';
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusXL,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radius10,
              ),
              child: const Icon(Icons.person, color: AppTheme.primaryColor),
            ),
            AppTheme.hSpacer12,
            const Text(AppTheme.titleChangeName),
          ],
        ),
        content: SingleChildScrollView(
          child: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: AppTheme.labelRealName,
              border: OutlineInputBorder(
                borderRadius: AppTheme.radiusS,
              ),
              counterText: '',
            ),
            maxLength: 50,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTheme.msgCancel),
          ),
          PrimaryButton(
            text: AppTheme.msgSave,
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;

              Navigator.pop(ctx);
              final success = await ref.read(userProvider.notifier).updateUser(
                realName: newName,
              );

              if (mounted) {
                if (success) {
                  // 更新 authProvider 中的用户信息
                  final updatedUser = ref.read(userProvider).user;
                  if (updatedUser != null) {
                    ref.read(authProvider.notifier).login(
                      user: updatedUser,
                      accessToken: authState.accessToken!,
                      refreshToken: authState.refreshToken!,
                    );
                  }
                  context.showSuccessSnackBar(AppTheme.msgNameUpdated);
                } else {
                  context.showErrorSnackBar(AppTheme.msgModifyFailed(ref.read(userProvider).error ?? ''));
                }
              }
            },
          ),
        ],
      ),
    ).then((_) {
      // 延迟到下一帧释放控制器，确保对话框 Widget 树已完全卸载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
      });
    });
  }

  /// 显示修改密码对话框
  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // 密码强度检测
            final newPwd = newPasswordController.text;
            String strengthText = '';
            Color strengthColor = AppTheme.grey500;
            if (newPwd.length >= 8 && newPwd.isNotEmpty) {
              final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(newPwd);
              final hasDigit = RegExp(r'\d').hasMatch(newPwd);
              final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(newPwd);
              if (hasLetter && hasDigit && hasSpecial) {
                strengthText = AppTheme.msgPasswordStrengthStrong;
                strengthColor = AppTheme.successColor;
              } else if (hasLetter && hasDigit) {
                strengthText = AppTheme.msgPasswordStrengthMedium;
                strengthColor = AppTheme.warningColor;
              } else {
                strengthText = AppTheme.msgPasswordStrengthWeak;
                strengthColor = AppTheme.errorColor;
              }
            }
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusXL,
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radius10,
                    ),
                    child: const Icon(Icons.lock, color: AppTheme.primaryColor),
                  ),
                  AppTheme.hSpacer12,
                  const Text(AppTheme.titleChangePassword),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordController,
                    decoration: InputDecoration(
                      labelText: AppTheme.labelOldPassword,
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.radiusS,
                      ),
                    ),
                    obscureText: true,
                  ),
                  AppTheme.spacer12,
                  TextField(
                    controller: newPasswordController,
                    decoration: InputDecoration(
                      labelText: AppTheme.labelNewPassword,
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.radiusS,
                      ),
                      helperText: '至少8位，需包含字母和数字',
                    ),
                    obscureText: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (strengthText.isNotEmpty)
                    Padding(
                      padding: AppTheme.marginTop4,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(strengthText, style: AppTheme.textCaption.copyWith(color: strengthColor)),
                      ),
                    ),
                  AppTheme.spacer12,
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: AppTheme.labelConfirmPassword,
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.radiusS,
                      ),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
              ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTheme.msgCancel),
          ),
          PrimaryButton(
            text: '修改',
            onPressed: () async {
              final oldPassword = oldPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (oldPassword.isEmpty || newPassword.isEmpty) {
                context.showWarningSnackBar(AppTheme.msgPasswordEmpty);
                return;
              }

              if (newPassword != confirmPassword) {
                context.showWarningSnackBar(AppTheme.msgPasswordMismatch);
                return;
              }

              // 使用统一的密码验证规则（与注册一致）
              final passwordError = FormValidators.password(newPassword);
              if (passwordError != null) {
                context.showWarningSnackBar(passwordError);
                return;
              }

              Navigator.pop(ctx);
              final success = await ref.read(userProvider.notifier).changePassword(
                oldPassword: oldPassword,
                newPassword: newPassword,
              );

              if (mounted) {
                if (success) {
                  // 密码修改成功后强制重新登录，确保旧 JWT token 失效
                  context.showSuccessSnackBar(AppTheme.msgPasswordChanged);
                  // 清除业务状态
                  ref.invalidate(healthRecordsProvider);
                  ref.invalidate(healthStatsProvider);
                  ref.invalidate(medicationProvider);
                  ref.invalidate(emergencyProvider);
                  ref.invalidate(userProvider);
                  ref.invalidate(notificationListProvider);
                  // 登出并跳转登录页
                  ref.read(authProvider.notifier).logout();
                  if (!mounted) return;
                  context.go(RoutePaths.login);
                } else {
                  context.showErrorSnackBar(
                    ref.read(userProvider).error?.isNotEmpty == true
                      ? '${AppTheme.msgPasswordChangeFailed}：${ref.read(userProvider).error}'
                      : AppTheme.msgOldPasswordIncorrect,
                  );
                }
              }
            },
          ),
        ],
      );
      });
    },
  ).then((_) {
    // 延迟到下一帧释放控制器，确保对话框 Widget 树已完全卸载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  });
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusXL,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radius10,
              ),
              child: const Icon(Icons.info, color: AppTheme.primaryColor),
            ),
            AppTheme.hSpacer12,
            const Text(AppTheme.titleAboutUs),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppTheme.appName} App', style: AppTheme.textTitle),
            AppTheme.spacer8,
            Text('版本: 1.0.0'),
            AppTheme.spacer12,
            Text('一款专为老年人及其子女设计的健康管理应用，帮助子女实时关注老人的健康状况。'),
          ],
        ),
        actions: [
          PrimaryButton(
            text: AppTheme.msgConfirm,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  /// 显示帮助对话框
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusXL,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radius10,
              ),
              child: const Icon(Icons.help, color: AppTheme.primaryColor),
            ),
            AppTheme.hSpacer12,
            const Text(AppTheme.titleHelpFeedback),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('使用帮助', style: AppTheme.textHeading),
            AppTheme.spacer8,
            Text('• 老人端：可记录健康数据、查看用药提醒、发起紧急呼叫'),
            AppTheme.spacer4,
            Text('• 子女端：可查看老人健康数据、位置信息、处理紧急呼叫'),
            AppTheme.spacer12,
            Text('如有问题或建议，请联系客服。'),
          ],
        ),
        actions: [
          PrimaryButton(
            text: AppTheme.msgConfirm,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  /// 显示退出登录对话框
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusXL,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radius10,
              ),
              child: const Icon(Icons.logout, color: AppTheme.errorColor),
            ),
            AppTheme.hSpacer12,
            const Text(AppTheme.labelLogout),
          ],
        ),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTheme.msgCancel),
          ),
          PrimaryButton(
            text: AppTheme.labelLogoutAction,
            onPressed: () {
              Navigator.pop(ctx);
              // 清除所有业务 Provider 状态，防止残留旧数据
              ref.invalidate(healthRecordsProvider);
              ref.invalidate(healthStatsProvider);
              ref.invalidate(medicationProvider);
              ref.invalidate(emergencyProvider);
              ref.invalidate(userProvider);
              ref.invalidate(notificationListProvider);
              // 执行登出（清除认证状态和 SignalR 连接）
              ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              context.go(RoutePaths.login);
            },
            gradient: const LinearGradient(
              colors: [AppTheme.errorColor, AppTheme.errorAccent],
            ),
          ),
        ],
      ),
    );
  }
}