import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/providers/emergency_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/emergency_service.dart';
import '../../../core/api/api_client.dart';
import 'health_record_page.dart';
import 'medication_page.dart';

/// 老人端首页
class ElderHomePage extends ConsumerStatefulWidget {
  const ElderHomePage({super.key});

  @override
  ConsumerState<ElderHomePage> createState() => _ElderHomePageState();
}

class _ElderHomePageState extends ConsumerState<ElderHomePage> {
  int _selectedIndex = 0;
  bool _isCalling = false;
  bool _isUploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    // 老人端使用大字体主题
    final theme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.2),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('关爱老人'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () => context.push('/notifications'),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: '健康',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication),
              label: '用药',
            ),
          ],
          selectedFontSize: 18,
          unselectedFontSize: 16,
          selectedItemColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 底部导航栏切换页面内容，不使用路由导航（避免 build 期间调用 setState）
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const HealthRecordPage();
      case 2:
        return const MedicationPage();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final authState = ref.watch(authProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 紧急呼叫按钮 - 醒目的红色大按钮
          _buildEmergencyCallButton(),
          const SizedBox(height: 24),

          // 用户信息卡片 - 渐变背景
          GradientCard(
            gradient: AppTheme.warmGradient,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // 头像区域：点击可上传新头像
                  GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            // 若有头像 URL 则显示网络图片
                            image: authState.user?.avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                      'http://192.168.100.199:5001${authState.user!.avatarUrl}',
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: authState.user?.avatarUrl == null
                              ? const Icon(Icons.person, size: 40, color: Colors.white)
                              : null,
                        ),
                        // 上传中遮罩
                        if (_isUploadingAvatar)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                            ),
                          ),
                        // 右下角相机图标
                        if (!_isUploadingAvatar)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.user?.realName ?? '用户',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '今天感觉怎么样？',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 快捷操作
          const Text(
            '快捷操作',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.95,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              AnimatedQuickCard(
                icon: Icons.favorite,
                title: '记录健康',
                subtitle: '血压、血糖、心率',
                color: Colors.red,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              AnimatedQuickCard(
                icon: Icons.medication,
                title: '用药提醒',
                subtitle: '查看今日用药',
                color: Colors.blue,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              AnimatedQuickCard(
                icon: Icons.people,
                title: '家庭成员',
                subtitle: '查看家人信息',
                color: Colors.green,
                onTap: () => context.push('/elder/family'),
              ),
              AnimatedQuickCard(
                icon: Icons.settings,
                title: '设置',
                subtitle: '个人信息设置',
                color: Colors.grey,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 紧急呼叫按钮 - 醒目的红色大按钮
  Widget _buildEmergencyCallButton() {
    return GestureDetector(
      onTap: () => _showEmergencyCallDialog(),
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.red, Colors.redAccent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(width: 12),
            const Text(
              '紧急呼叫',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示紧急呼叫确认对话框
  void _showEmergencyCallDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.emergency, color: Colors.red, size: 32),
            ),
            const SizedBox(width: 16),
            const Text('紧急呼叫'),
          ],
        ),
        content: const Text(
          '确定要发起紧急呼叫吗？\n您的家人将收到紧急通知。',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.red, Colors.redAccent],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _isCalling ? null : () async {
                Navigator.pop(ctx);
                setState(() => _isCalling = true);

                try {
                  final service = EmergencyService(ref.read(apiClientProvider).dio);
                  final call = await service.createCall();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('紧急呼叫已发送，家人将尽快联系您'),
                        backgroundColor: AppTheme.successColor,
                        duration: const Duration(seconds: 3),
                      ),
                    );

                    // 显示呼叫成功对话框
                    _showCallSuccessDialog(call);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('呼叫失败: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                } finally {
                  setState(() => _isCalling = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: _isCalling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('确认呼叫'),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示呼叫成功对话框
  void _showCallSuccessDialog(call) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 16),
            const Text('呼叫已发送'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '您的紧急呼叫已成功发送给家人。',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              '呼叫时间: ${call.formattedTime}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            text: '确定',
            onPressed: () => Navigator.pop(ctx),
            gradient: const LinearGradient(
              colors: [Colors.green, Colors.lightGreen],
            ),
          ),
        ],
      ),
    );
  }

  /// 选择并上传头像
  ///
  /// 弹出底部菜单供用户选择相册或拍照，选取后自动上传到服务端。
  Future<void> _pickAndUploadAvatar() async {
    // 弹出选择来源的底部菜单
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '更换头像',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('从相册选择', style: TextStyle(fontSize: 18)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('拍照', style: TextStyle(fontSize: 18)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploadingAvatar = true);

      final avatarUrl = await ref.read(userProvider.notifier).uploadAvatar(image.path);

      if (mounted) {
        if (avatarUrl != null) {
          // 同时更新 authProvider 中的用户信息
          await ref.read(authProvider.notifier).login(
                user: ref.read(userProvider).user!,
                accessToken: ref.read(authProvider).accessToken!,
                refreshToken: ref.read(authProvider).refreshToken!,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('头像更新成功'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('头像上传失败，请重试'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('头像上传失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }
}