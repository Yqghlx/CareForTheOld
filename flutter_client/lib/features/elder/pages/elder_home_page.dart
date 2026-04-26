import '../../../core/router/route_paths.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:battery_plus/battery_plus.dart';

import '../../../shared/models/emergency_call.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/providers/notification_record_provider.dart';
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
  bool _isUploadingAvatar = false;

  // 长按紧急呼叫相关状态
  bool _isLongPressing = false;
  double _longPressProgress = 0.0;
  static const double _longPressDurationSeconds = 2.0;
  bool _longPressCancelled = false; // 用于 dispose 时取消异步操作

  @override
  void initState() {
    super.initState();
    _longPressCancelled = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListProvider.notifier).loadNotifications();
    });
  }

  @override
  void dispose() {
    // 取消所有进行中的长按异步操作
    _longPressCancelled = true;
    super.dispose();
  }

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
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: '通知',
                  onPressed: () => context.push(RoutePaths.notifications),
                ),
                // 未读通知红点
                Positioned(
                  right: 8,
                  top: 8,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final unreadCount = ref.watch(notificationListProvider.select((s) => s.unreadCount));
                      if (unreadCount == 0) return const SizedBox.shrink();
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '设置',
              onPressed: () => context.push(RoutePaths.settings),
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
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
          unselectedItemColor: AppTheme.grey500,
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 使用 IndexedStack 保持所有 Tab 页面状态，切换时不会重新构建
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeContent(),
        const HealthRecordPage(),
        const MedicationPage(),
      ],
    );
  }

  Widget _buildHomeContent() {
    final authState = ref.watch(authProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(notificationListProvider.notifier).loadNotifications();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppTheme.paddingAll20,
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
              padding: AppTheme.paddingAll24,
              child: Row(
                children: [
                  // 头像区域：点击可上传新头像
                  Semantics(
                    button: true,
                    label: '更换头像，点击上传新照片',
                    child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: AppTheme.radiusL,
                          child: Container(
                            width: 64,
                            height: 64,
                            color: Colors.white.withValues(alpha: 0.2),
                            child: authState.user?.avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: authState.user!.avatarUrl!.startsWith('http')
                                        ? authState.user!.avatarUrl!
                                        : '${AppConfig.current.apiBaseUrl.replaceFirst('/api/v1', '')}${authState.user!.avatarUrl}',
                                    fit: BoxFit.cover,
                                    width: 64,
                                    height: 64,
                                    memCacheWidth: 256,
                                    memCacheHeight: 256,
                                    maxWidthDiskCache: 512,
                                    maxHeightDiskCache: 512,
                                    errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40, color: Colors.white),
                                  )
                                : const Icon(Icons.person, size: 40, color: Colors.white),
                          ),
                        ),
                        // 上传中遮罩
                        if (_isUploadingAvatar)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: AppTheme.radiusL,
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
                                borderRadius: AppTheme.radiusXS,
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
                color: AppTheme.errorColor,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              AnimatedQuickCard(
                icon: Icons.medication,
                title: '用药提醒',
                subtitle: '查看今日用药',
                color: AppTheme.infoBlue,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              AnimatedQuickCard(
                icon: Icons.people,
                title: '家庭成员',
                subtitle: '查看家人信息',
                color: AppTheme.successColor,
                onTap: () => context.push(RoutePaths.elderFamily),
              ),
              AnimatedQuickCard(
                icon: Icons.diversity_3,
                title: '邻里圈',
                subtitle: '附近邻居互助',
                color: Colors.teal,
                onTap: () => context.push(RoutePaths.neighborCircle),
              ),
              AnimatedQuickCard(
                icon: Icons.volunteer_activism,
                title: '邻里互助',
                subtitle: '求助与帮助邻居',
                color: AppTheme.warningColor,
                onTap: () => context.push('/neighbor-help'),
              ),
              AnimatedQuickCard(
                icon: Icons.settings,
                title: '设置',
                subtitle: '个人信息设置',
                color: AppTheme.grey500,
                onTap: () => context.push(RoutePaths.settings),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  /// 紧急呼叫按钮 - 长按 2 秒触发，带进度指示器，松手取消
  Widget _buildEmergencyCallButton() {
    return Semantics(
      button: true,
      label: _isLongPressing ? '正在呼叫中，松手取消' : '紧急呼叫按钮，长按2秒发起呼叫',
      child: GestureDetector(
      // 按下开始计时
      onPanDown: (_) => _startLongPressTimer(),
      // 松手或取消时停止计时
      onPanEnd: (_) => _cancelLongPressTimer(),
      onPanCancel: () => _cancelLongPressTimer(),
      // 短按提示
      onTap: () {
        if (!_isLongPressing) {
          ScaffoldMessenger.of(context).clearSnackBars();
          context.showSnackBar('请长按按钮 2 秒发起紧急呼叫');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isLongPressing
                ? [AppTheme.errorAccent, AppTheme.errorColor]
                : [AppTheme.errorColor, AppTheme.errorAccent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: AppTheme.radiusXL,
          boxShadow: [
            BoxShadow(
              color: AppTheme.errorColor.withValues(alpha: _isLongPressing ? 0.7 : 0.4),
              blurRadius: _isLongPressing ? 24 : 16,
              spreadRadius: _isLongPressing ? 4 : 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 进度指示器（长按时显示）
            if (_isLongPressing)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    value: _longPressProgress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            // 内容
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isLongPressing ? Icons.phone_in_talk : Icons.emergency,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isLongPressing ? '正在呼叫...' : '长按紧急呼叫',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                // 长按时显示进度提示
                if (_isLongPressing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '松手取消',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// 开始长按计时器
  void _startLongPressTimer() {
    HapticFeedback.mediumImpact();
    _longPressCancelled = false;
    setState(() {
      _isLongPressing = true;
      _longPressProgress = 0.0;
    });

    // 使用动画驱动进度
    Future<void> updateProgress() async {
      const updateInterval = Duration(milliseconds: 50);
      final totalSteps = (_longPressDurationSeconds * 1000 / updateInterval.inMilliseconds).round();

      for (int i = 0; i <= totalSteps && _isLongPressing && !_longPressCancelled; i++) {
        await Future.delayed(updateInterval);
        // 检查是否已取消或 Widget 已销毁
        if (!_isLongPressing || _longPressCancelled || !mounted) return;

        setState(() {
          _longPressProgress = (i / totalSteps).clamp(0.0, 1.0);
        });
      }

      // 进度到达 100%，触发呼叫
      if (mounted && _isLongPressing && !_longPressCancelled && _longPressProgress >= 1.0) {
        setState(() => _isLongPressing = false);
        _performEmergencyCall();
      }
    }

    updateProgress();
  }

  /// 取消长按计时器
  void _cancelLongPressTimer() {
    _longPressCancelled = true;
    if (_isLongPressing && _longPressProgress < 1.0) {
      HapticFeedback.lightImpact();
      setState(() {
        _isLongPressing = false;
        _longPressProgress = 0.0;
      });
      // 提示用户已取消
      ScaffoldMessenger.of(context).clearSnackBars();
      context.showSnackBar('已取消，请长按 2 秒发起呼叫');
    }
  }

  /// 执行紧急呼叫（长按 2 秒后直接触发）
  Future<void> _performEmergencyCall() async {
    HapticFeedback.heavyImpact();
    try {
      // 并行获取 GPS 位置和电池电量（不阻塞呼叫，获取失败也不影响）
      double? latitude;
      double? longitude;
      int? batteryLevel;

      final results = await Future.wait([
        _getLocation(),
        _getBatteryLevel(),
      ]);

      if (results[0] != null) {
        latitude = (results[0] as Position).latitude;
        longitude = (results[0] as Position).longitude;
      }
      batteryLevel = results[1] as int?;

      final service = EmergencyService(ref.read(apiClientProvider).dio);
      final call = await service.createCall(
        latitude: latitude,
        longitude: longitude,
        batteryLevel: batteryLevel,
      );

      if (mounted) {
        context.showSuccessSnackBar('紧急呼叫已发送，已通知家人和附近邻居');
        _showCallSuccessDialog(call);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('呼叫失败，请直接拨打电话联系家人');
      }
    }
  }

  /// 获取当前位置（获取失败返回 null，不影响呼叫流程）
  Future<Position?> _getLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  /// 获取电池电量百分比（获取失败返回 null）
  Future<int?> _getBatteryLevel() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      return level;
    } catch (_) {
      return null;
    }
  }

  /// 显示呼叫成功对话框
  void _showCallSuccessDialog(EmergencyCall call) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusXL,
        ),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radiusS,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.successColor, size: 32),
            ),
            const SizedBox(width: 16),
            const Text('呼叫已发送'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '您的紧急呼叫已成功发送，已通知家人和附近邻居。',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              '呼叫时间: ${call.formattedTime}',
              style: TextStyle(fontSize: 16, color: AppTheme.grey600),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            text: '确定',
            onPressed: () => Navigator.pop(ctx),
            gradient: const LinearGradient(
              colors: [AppTheme.successColor, Colors.lightGreen],
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
              padding: AppTheme.paddingAll16,
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
          if (mounted && context.mounted) {
            context.showSuccessSnackBar('头像更新成功');
          }
        } else {
          if (mounted && context.mounted) {
            context.showErrorSnackBar('头像上传失败，请重试');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('头像上传失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }
}