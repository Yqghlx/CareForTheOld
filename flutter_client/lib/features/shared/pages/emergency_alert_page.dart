import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../shared/providers/emergency_provider.dart';
import '../services/emergency_alert_service.dart';

/// 全屏紧急警报页面
///
/// 当收到紧急呼叫时全屏覆盖显示，伴随强震动和警报铃声。
/// 必须点击"立即响应"或"拨打电话"才能关闭。
class EmergencyAlertPage extends ConsumerStatefulWidget {
  const EmergencyAlertPage({super.key});

  @override
  ConsumerState<EmergencyAlertPage> createState() => _EmergencyAlertPageState();
}

class _EmergencyAlertPageState extends ConsumerState<EmergencyAlertPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    // 脉冲动画（红色背景呼吸灯效果）
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alert = EmergencyAlertService.instance;
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false, // 禁止返回键关闭
      child: Scaffold(
        backgroundColor: Colors.red,
        body: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: size.width,
              height: size.height,
              color: Colors.red.withValues(alpha: (0.7 + _pulseAnimation.value).clamp(0.0, 1.0)),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 警报图标
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 80,
                    ),
                    const SizedBox(height: 16),

                    // 标题
                    Text(
                      alert.isReminder ? '紧急呼叫仍未响应！' : '紧急呼叫！',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 老人姓名
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: AppTheme.radiusL,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Text(
                            alert.elderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      alert.isReminder ? '已超过3分钟未得到响应' : '发起了紧急呼叫，请立即响应！',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // 操作按钮
                    _buildRespondButton(context),

                    const SizedBox(height: 16),

                    _buildCallButton(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// "立即响应"按钮
  Widget _buildRespondButton(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: _isResponding ? null : _respond,
        icon: _isResponding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              )
            : const Icon(Icons.check_circle_outline, size: 28),
        label: Text(
          _isResponding ? '处理中...' : '立即响应',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radius3XL,
          ),
        ),
      ),
    );
  }

  /// "拨打电话"按钮
  Widget _buildCallButton(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 64,
      child: OutlinedButton.icon(
        onPressed: _callElder,
        icon: const Icon(Icons.phone, size: 28, color: Colors.white),
        label: const Text(
          '拨打电话',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radius3XL,
          ),
        ),
      ),
    );
  }

  /// 立即响应
  Future<void> _respond() async {
    setState(() => _isResponding = true);

    try {
      final callId = EmergencyAlertService.instance.callId;
      await ref.read(emergencyProvider.notifier).respondCall(callId);

      // 停止警报
      await EmergencyAlertService.instance.stopAlert();

      if (mounted) {
        // 返回到紧急页面查看详情
        Navigator.of(context).pop();
        context.showSuccessSnackBar('已标记处理');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('响应失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
      }
    }
  }

  /// 拨打电话
  Future<void> _callElder() async {
    // 获取老人电话号码（从紧急呼叫列表中查找）
    final state = ref.read(emergencyProvider);
    String? phoneNumber;

    for (final call in state.unreadCalls) {
      if (call.id == EmergencyAlertService.instance.callId) {
        phoneNumber = call.elderPhoneNumber;
        break;
      }
    }

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else {
      if (mounted) {
        context.showErrorSnackBar('无法获取老人电话号码');
      }
    }
  }
}
