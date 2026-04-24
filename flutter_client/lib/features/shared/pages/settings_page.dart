import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../shared/widgets/common_cards.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLocationSetting();
    _loadAppVersion();
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
        memCacheWidth: 256,
        memCacheHeight: 256,
        maxWidthDiskCache: 512,
        maxHeightDiskCache: 512,
        errorWidget: (_, __, ___) => Icon(Icons.person, size: iconSize, color: Colors.white),
      );
    }
    return Icon(Icons.person, size: iconSize, color: Colors.white);
  }

  /// 加载定位设置
  Future<void> _loadLocationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _locationEnabled = prefs.getBool('location_enabled') ?? true;
      _isLoadingLocation = false;
    });
  }

  /// 加载应用版本信息
  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = '${info.version} (${info.buildNumber})');
  }

  /// 保存定位设置并实际控制位置上报服务
  Future<void> _saveLocationSetting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_enabled', enabled);
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
        title: const Text('设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息卡片
            GradientCard(
              gradient: AppTheme.warmGradient,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildAvatar(
                          userState.user?.avatarUrl ?? authState.user?.avatarUrl,
                          40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userState.user?.realName ?? authState.user?.realName ?? '用户',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userState.user?.phoneNumber ?? authState.user?.phoneNumber ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 个人信息
            const Text(
              '个人信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: Icons.person_outline,
                    title: '修改姓名',
                    subtitle: userState.user?.realName ?? authState.user?.realName ?? '未设置',
                    onTap: () => _showEditNameDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    icon: Icons.lock_outline,
                    title: '修改密码',
                    subtitle: '更改登录密码',
                    onTap: () => _showChangePasswordDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 功能设置（老人端显示定位开关）
            if (isElder) ...[
              const Text(
                '功能设置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 24),
            ],

            // 其他设置
            const Text(
              '其他',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: '关于我们',
                    subtitle: '关爱老人 App ${_appVersion.isNotEmpty ? "v$_appVersion" : ""}',
                    onTap: () => _showAboutDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSettingItem(
                    icon: Icons.help_outline,
                    title: '帮助与反馈',
                    subtitle: '使用帮助、问题反馈',
                    onTap: () => _showHelpDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 退出登录按钮
            PrimaryButton(
              text: '退出登录',
              onPressed: () => _showLogoutDialog(),
              gradient: const LinearGradient(
                colors: [Colors.red, Colors.redAccent],
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null && onTap != null)
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
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
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Text('修改姓名'),
          ],
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: '姓名',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            counterText: '',
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          PrimaryButton(
            text: '保存',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('姓名修改成功'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('修改失败: ${ref.read(userProvider).error}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
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
            Color strengthColor = Colors.grey;
            if (newPwd.length >= 8 && newPwd.isNotEmpty) {
              final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(newPwd);
              final hasDigit = RegExp(r'\d').hasMatch(newPwd);
              final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(newPwd);
              if (hasLetter && hasDigit && hasSpecial) {
                strengthText = '密码强度：强';
                strengthColor = Colors.green;
              } else if (hasLetter && hasDigit) {
                strengthText = '密码强度：中';
                strengthColor = Colors.orange;
              } else {
                strengthText = '密码强度：弱';
                strengthColor = Colors.red;
              }
            }
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text('修改密码'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordController,
                    decoration: InputDecoration(
                      labelText: '旧密码',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    decoration: InputDecoration(
                      labelText: '新密码',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: '至少8位，需包含字母和数字',
                    ),
                    obscureText: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (strengthText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(strengthText, style: TextStyle(fontSize: 12, color: strengthColor)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: '确认新密码',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          PrimaryButton(
            text: '修改',
            onPressed: () async {
              final oldPassword = oldPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (oldPassword.isEmpty || newPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('密码不能为空'),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('两次输入的新密码不一致'),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
                return;
              }

              // 使用统一的密码验证规则（与注册一致）
              final passwordError = FormValidators.password(newPassword);
              if (passwordError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(passwordError),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('密码修改成功，请重新登录'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                  // 清除业务状态
                  ref.invalidate(healthRecordsProvider);
                  ref.invalidate(healthStatsProvider);
                  ref.invalidate(medicationProvider);
                  ref.invalidate(emergencyProvider);
                  ref.invalidate(userProvider);
                  ref.invalidate(notificationListProvider);
                  // 登出并跳转登录页
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('修改失败: ${ref.read(userProvider).error ?? "旧密码不正确"}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
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
    // 对话框关闭后释放控制器，防止内存泄漏
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  });
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Text('关于我们'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('关爱老人 App', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('版本: 1.0.0'),
            SizedBox(height: 12),
            Text('一款专为老年人及其子女设计的健康管理应用，帮助子女实时关注老人的健康状况。'),
          ],
        ),
        actions: [
          PrimaryButton(
            text: '确定',
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
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.help, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Text('帮助与反馈'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('使用帮助', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• 老人端：可记录健康数据、查看用药提醒、发起紧急呼叫'),
            SizedBox(height: 4),
            Text('• 子女端：可查看老人健康数据、位置信息、处理紧急呼叫'),
            SizedBox(height: 12),
            Text('如有问题或建议，请联系客服。'),
          ],
        ),
        actions: [
          PrimaryButton(
            text: '确定',
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
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('退出登录'),
          ],
        ),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          PrimaryButton(
            text: '退出',
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
              context.go('/login');
            },
            gradient: const LinearGradient(
              colors: [Colors.red, Colors.redAccent],
            ),
          ),
        ],
      ),
    );
  }
}