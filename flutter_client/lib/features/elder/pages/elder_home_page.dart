import '../../../core/constants/api_endpoints.dart';
import '../../../core/router/route_paths.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/notification_badge.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:battery_plus/battery_plus.dart';

import '../../../shared/models/emergency_call.dart';
import '../../../shared/models/health_stats.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/extensions/date_format_extension.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/providers/notification_record_provider.dart';
import '../../shared/services/emergency_service.dart';
import '../providers/health_provider.dart';
import '../providers/medication_provider.dart';
import '../../../core/api/api_client.dart';
import 'health_record_page.dart';
import 'medication_page.dart';
import '../../../core/extensions/api_error_extension.dart';

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
  bool _isCalling = false; // 紧急呼叫防重复提交

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
          title: const Text(AppTheme.appName),
          automaticallyImplyLeading: false,
          actions: [
            const NotificationBadgeButton(),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: AppTheme.tooltipSettings,
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
    final user = ref.watch(authProvider.select((s) => s.user));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProvider);
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
          AppTheme.spacer24,

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
                            color: AppTheme.cardColor.withValues(alpha: 0.2),
                            child: user?.avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: user!.avatarUrl!.startsWith('http')
                                        ? user.avatarUrl!
                                        : '${AppConfig.current.apiBaseUrl.replaceFirst(ApiEndpoints.apiPathPrefix, '')}${user.avatarUrl}',
                                    fit: BoxFit.cover,
                                    width: 64,
                                    height: 64,
                                    fadeInDuration: AppTheme.duration200ms,
                                    memCacheWidth: 256,
                                    memCacheHeight: 256,
                                    maxWidthDiskCache: 512,
                                    maxHeightDiskCache: 512,
                                    errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40, color: AppTheme.cardColor),
                                  )
                                : const Icon(Icons.person, size: 40, color: AppTheme.cardColor),
                          ),
                        ),
                        // 上传中遮罩
                        if (_isUploadingAvatar)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.overlayDark,
                              borderRadius: AppTheme.radiusL,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(AppTheme.cardColor),
                                ),
                              ),
                            ),
                          ),
                        // 右下角相机图标
                        if (!_isUploadingAvatar)
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: AppTheme.paddingAll6,
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: AppTheme.radiusXS,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ),
                  AppTheme.hSpacer20,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.realName ?? '用户',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cardColor,
                        ),
                      ),
                      AppTheme.spacer6,
                      Text(
                        '今天感觉怎么样？',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.cardColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 今日健康摘要
          _buildHealthSummary(),
          AppTheme.spacer20,

          // 用药提醒
          _buildMedicationReminder(),
          AppTheme.spacer20,

          // 快捷操作
          const Text(
            '快捷操作',
            style: AppTheme.textSectionTitle,
          ),
          AppTheme.spacer20,

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
                color: AppTheme.tealColor,
                onTap: () => context.push(RoutePaths.neighborCircle),
              ),
              AnimatedQuickCard(
                icon: Icons.volunteer_activism,
                title: '邻里互助',
                subtitle: '求助与帮助邻居',
                color: AppTheme.warningColor,
                onTap: () => context.push(RoutePaths.neighborHelp),
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

  /// 今日健康摘要卡片：显示最近一次血压/血糖/心率/体温
  Widget _buildHealthSummary() {
    final statsAsync = ref.watch(healthStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(AppTheme.titleTodayHealth, style: AppTheme.textSectionTitle),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 1),
              child: const Text(AppTheme.labelViewDetails, style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        AppTheme.spacer12,
        statsAsync.when(
          data: (stats) {
            if (stats.isEmpty) {
              return StandardCard(
                child: Center(
                  child: Padding(
                    padding: AppTheme.paddingAll24,
                    child: Column(
                      children: [
                        const Icon(Icons.favorite_border, size: 40, color: AppTheme.grey400),
                        AppTheme.spacer8,
                        const Text(AppTheme.msgNoHealthRecord, style: AppTheme.textSecondary16),
                        AppTheme.spacer8,
                        PrimaryButton(
                          text: AppTheme.labelGoRecord,
                          onPressed: () => setState(() => _selectedIndex = 1),
                          gradient: const LinearGradient(
                            colors: [AppTheme.errorColor, AppTheme.errorAccent],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats.map((stat) {
                final hasData = stat.latestValue != null;
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - AppTheme.paddingAll20.horizontal - 12) / 2,
                  child: StandardCard(
                    padding: AppTheme.paddingAll12,
                    onTap: () => setState(() => _selectedIndex = 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _healthTypeIcon(stat.typeName),
                              size: 20,
                              color: stat.hasWarning ? AppTheme.warningColor : AppTheme.primaryColor,
                            ),
                            AppTheme.hSpacer8,
                            Expanded(
                              child: Text(
                                stat.typeName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (stat.trend != null)
                              Icon(stat.trendIcon, size: 16, color: stat.trendColor),
                          ],
                        ),
                        AppTheme.spacer8,
                        if (hasData)
                          Text(
                            _formatHealthValue(stat),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          )
                        else
                          const Text('--', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.grey400)),
                        if (hasData && stat.latestRecordedAt != null)
                          Text(
                            stat.latestRecordedAt!.toFriendlyDate(),
                            style: AppTheme.textCaption,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: Padding(
            padding: AppTheme.paddingAll24,
            child: CircularProgressIndicator(),
          )),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// 用药提醒卡片：显示今日待服用药物
  Widget _buildMedicationReminder() {
    final todayPending = ref.watch(medicationProvider.select((s) => s.todayPending));
    final isLoading = ref.watch(medicationProvider.select((s) => s.isLoading));
    final pendingCount = ref.watch(medicationProvider.select((s) => s.pendingCount));
    final takenCount = ref.watch(medicationProvider.select((s) => s.takenCount));
    final pendingList = todayPending.where((l) => l.isPending).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(AppTheme.titleTodayMedication, style: AppTheme.textSectionTitle),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.15),
                  borderRadius: AppTheme.radiusS,
                ),
                child: Text(
                  '$pendingCount ${AppTheme.labelPendingCount}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.warningColor, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        AppTheme.spacer12,
        if (isLoading)
          const Center(child: Padding(
            padding: AppTheme.paddingAll24,
            child: CircularProgressIndicator(),
          ))
        else if (todayPending.isEmpty)
          StandardCard(
            child: Center(
              child: Padding(
                padding: AppTheme.paddingAll24,
                child: Column(
                  children: [
                    const Icon(Icons.medication_outlined, size: 40, color: AppTheme.grey400),
                    AppTheme.spacer8,
                    const Text(AppTheme.msgNoMedicationPlanToday, style: AppTheme.textSecondary16),
                  ],
                ),
              ),
            ),
          )
        else if (pendingList.isEmpty)
          StandardCard(
            child: Center(
              child: Padding(
                padding: AppTheme.paddingAll16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.successColor, size: 24),
                    AppTheme.hSpacer8,
                    Text(
                      '今日 $takenCount 项已全部完成',
                      style: const TextStyle(fontSize: 16, color: AppTheme.successColor),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...pendingList.take(3).map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: StandardCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () => setState(() => _selectedIndex = 2),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.infoBlue.withValues(alpha: 0.12),
                      borderRadius: AppTheme.radiusS,
                    ),
                    child: const Icon(Icons.medication, color: AppTheme.infoBlue, size: 24),
                  ),
                  AppTheme.hSpacer12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.medicineName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          log.scheduledAt.toTimeString(),
                          style: AppTheme.textSecondary16,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.grey400),
                ],
              ),
            ),
          )),
      ],
    );
  }

  /// 根据健康类型名称返回图标
  IconData _healthTypeIcon(String typeName) {
    switch (typeName) {
      case '血压': return Icons.favorite;
      case '血糖': return Icons.water_drop;
      case '心率': return Icons.monitor_heart;
      case '体温': return Icons.thermostat;
      default: return Icons.analytics;
    }
  }

  /// 格式化健康数据显示值
  String _formatHealthValue(HealthStats stat) {
    if (stat.latestValue == null) return '--';
    switch (stat.typeName) {
      case '血压':
        // 血压的 latestValue 是收缩压，同时有 average7Days 可以参考
        return '${stat.latestValue!.toInt()} mmHg';
      case '血糖':
        return '${stat.latestValue!.toStringAsFixed(1)} mmol/L';
      case '心率':
        return '${stat.latestValue!.toInt()} 次/分';
      case '体温':
        return '${stat.latestValue!.toStringAsFixed(1)} °C';
      default:
        return stat.latestValue!.toStringAsFixed(1);
    }
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
          context.showSnackBar(AppTheme.msgEmergencyLongPress);
        }
      },
      child: RepaintBoundary(
        child: AnimatedContainer(
        duration: AppTheme.duration100ms,
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
                  padding: AppTheme.paddingAll8,
                  child: CircularProgressIndicator(
                    value: _longPressProgress,
                    strokeWidth: 6,
                    backgroundColor: AppTheme.cardColor.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.cardColor),
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
                      color: AppTheme.cardColor,
                      size: 40,
                    ),
                    AppTheme.hSpacer12,
                    Text(
                      _isLongPressing ? '正在呼叫...' : '长按紧急呼叫',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cardColor,
                      ),
                    ),
                  ],
                ),
                // 长按时显示进度提示
                if (_isLongPressing)
                  Padding(
                    padding: AppTheme.marginTop4,
                    child: Text(
                      '松手取消',
                      style: AppTheme.textBody16.copyWith(
                        color: AppTheme.cardColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
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
      final updateInterval = AppTheme.duration50ms;
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
      context.showSnackBar(AppTheme.msgEmergencyCancelled);
    }
  }

  /// 执行紧急呼叫（长按 2 秒后直接触发，防重复提交）
  Future<void> _performEmergencyCall() async {
    if (_isCalling) return;
    _isCalling = true;
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

      final locationOk = results[0] != null;
      if (locationOk) {
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
        // 位置获取失败时额外提示用户
        if (!locationOk) {
          context.showWarningSnackBar(AppTheme.msgEmergencyLocationFailed);
        }
        context.showSuccessSnackBar(AppTheme.msgEmergencySent);
        _showCallSuccessDialog(call);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(errorMessageFrom(e, fallback: AppTheme.msgEmergencyFailed));
      }
    } finally {
      _isCalling = false;
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
        timeLimit: AppTheme.duration5s,
      );
    } catch (e) {
      AppLogger.warning('获取GPS位置失败: $e');
      return null;
    }
  }

  /// 获取电池电量百分比（获取失败返回 null）
  Future<int?> _getBatteryLevel() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      return level;
    } catch (e) {
      AppLogger.warning('获取电池电量失败: $e');
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
              child: const Icon(Icons.check_circle, color: AppTheme.successColor, size: AppTheme.iconSizeXl),
            ),
            AppTheme.hSpacer16,
            const Text(AppTheme.titleCallSent),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppTheme.msgCallSentDetail,
              style: AppTheme.textBody16,
            ),
            AppTheme.spacer12,
            Text(
              '呼叫时间: ${call.formattedTime}',
              style: AppTheme.textSecondary16,
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            text: AppTheme.msgConfirm,
            onPressed: () => Navigator.pop(ctx),
            gradient: const LinearGradient(
              colors: [AppTheme.successColor, AppTheme.successLight],
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
        borderRadius: AppTheme.radiusTopXL,
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: AppTheme.paddingAll16,
              child: Text(
                AppTheme.labelChangeAvatar,
                style: AppTheme.textLargeTitle,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text(AppTheme.labelFromAlbum, style: AppTheme.textBody18),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text(AppTheme.labelTakePhoto, style: AppTheme.textBody18),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            AppTheme.spacer8,
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: AppTheme.avatarMaxSize,
        maxHeight: AppTheme.avatarMaxSize,
        imageQuality: AppTheme.avatarImageQuality,
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
            context.showSuccessSnackBar(AppTheme.msgAvatarUpdated);
          }
        } else {
          if (mounted && context.mounted) {
            context.showErrorSnackBar(AppTheme.msgAvatarFailed);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(errorMessageFrom(e, fallback: AppTheme.msgAvatarFailed));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }
}