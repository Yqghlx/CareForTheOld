import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/pref_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../shared/services/location_service.dart';

/// 位置上报服务（老人端后台定时上报）
///
/// 使用 Timer.periodic 定时获取 GPS 坐标并上报到服务端。
/// 内置网络连接检查、指数退避重试机制和错误恢复逻辑，
/// 保证在弱网或临时故障场景下仍具备良好的容错能力。
class LocationReporterService {
  final LocationService _service;
  final ConnectivityService _connectivityService;
  final OfflineQueueService _offlineQueue;
  Timer? _timer;
  StreamSubscription<bool>? _networkSubscription;
  bool _isRunning = false;

  /// 上报间隔（默认 5 分钟）
  static const Duration _reportInterval = AppTheme.duration5min;

  /// 最大重试次数
  static const int _maxRetries = 3;

  /// 基础退避延迟（秒）
  static const int _baseBackoffSeconds = 2;

  /// 连续失败计数，用于计算退避时间
  int _consecutiveFailures = 0;

  LocationReporterService(this._service, this._connectivityService, this._offlineQueue);

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 启动位置上报
  Future<bool> start() async {
    if (_isRunning) return true;

    // 检查定位开关设置
    final prefs = await SharedPreferences.getInstance();
    final locationEnabled = prefs.getBool(PrefKeys.locationEnabled) ?? true;
    if (!locationEnabled) {
      debugPrint('[位置上报] 定位上报已关闭');
      return false;
    }

    // 检查并请求定位权限
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[位置上报] 定位服务未开启');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[位置上报] 定位权限被拒绝');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[位置上报] 定位权限永久被拒绝');
      return false;
    }

    // 立即上报一次位置（带重试）
    await _reportLocationWithRetry();

    // 启动定时器
    _timer = Timer.periodic(_reportInterval, (_) => _reportLocationIfEnabled());
    _isRunning = true;
    _consecutiveFailures = 0;

    // 监听网络恢复，恢复后立即补报一次位置
    _networkSubscription = _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline && _isRunning) {
        debugPrint('[位置上报] 网络已恢复，立即补报位置');
        _reportLocationWithRetry();
      }
    });

    debugPrint('[位置上报] 服务已启动，间隔 ${_reportInterval.inMinutes} 分钟');
    return true;
  }

  /// 停止位置上报
  void stop() {
    _timer?.cancel();
    _timer = null;
    _networkSubscription?.cancel();
    _networkSubscription = null;
    _isRunning = false;
    _consecutiveFailures = 0;
    debugPrint('[位置上报] 服务已停止');
  }

  /// 检查并上报位置（根据设置决定是否上报）
  Future<void> _reportLocationIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final locationEnabled = prefs.getBool(PrefKeys.locationEnabled) ?? true;
    if (!locationEnabled) {
      debugPrint('[位置上报] 定位上报已关闭，跳过本次上报');
      return;
    }
    await _reportLocationWithRetry();
  }

  /// 带重试的位置上报（最多 3 次，指数退避）
  ///
  /// 每次失败后等待时间按 2^retryCount 秒递增（2s、4s、8s），
  /// 并叠加少量随机抖动以避免请求风暴。
  Future<void> _reportLocationWithRetry() async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      // 上报前先检查网络连接
      final isOnline = await _connectivityService.checkOnline();
      if (!isOnline) {
        debugPrint('[位置上报] 网络不可用，位置上报暂停（等待网络恢复）');
        // 网络断开时不消耗重试次数，直接返回等待下次定时器触发
        return;
      }

      final success = await _reportLocation();
      if (success) {
        // 上报成功，重置失败计数
        _consecutiveFailures = 0;
        return;
      }

      _consecutiveFailures++;

      if (attempt < _maxRetries - 1) {
        // 指数退避：基础延迟 * 2^attempt + 随机抖动（0~1秒）
        final backoffSeconds = _baseBackoffSeconds * pow(2, attempt);
        final jitter = Random().nextInt(1000); // 0~999 毫秒
        final delay = Duration(
          seconds: backoffSeconds.toInt(),
          milliseconds: jitter,
        );
        debugPrint('[位置上报] 第 ${attempt + 1} 次上报失败，${delay.inSeconds} 秒后重试...');
        await Future.delayed(delay);
      }
    }

    debugPrint('[位置上报] 已达最大重试次数 ($_maxRetries)，本次上报放弃，等待下次定时触发');
  }

  /// 单次位置上报（获取 GPS + 发送到服务端）
  ///
  /// 返回 true 表示上报成功，false 表示失败。
  /// 离线时自动将位置数据存入离线队列，等待网络恢复后上传。
  Future<bool> _reportLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: AppTheme.duration10s,
      );

      debugPrint('[位置上报] 获取位置: ${position.latitude}, ${position.longitude}, 精度: ${position.accuracy}m');

      final isOnline = await _connectivityService.checkOnline();
      if (!isOnline) {
        // 离线：存入队列
        await _offlineQueue.enqueue('location', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        });
        debugPrint('[位置上报] 网络不可用，位置已存入离线队列');
        return true; // 入队成功视为成功，不触发重试
      }

      await _service.reportLocation(
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
      );
      debugPrint('[位置上报] 上报成功');
      return true;
    } catch (e) {
      debugPrint('[位置上报] 上报失败: $e');
      return false;
    }
  }

  /// 手动上报一次位置（用于用户主动触发，使用高精度定位）
  Future<bool> reportNow() async {
    // 手动上报前也检查网络
    final isOnline = await _connectivityService.checkOnline();
    if (!isOnline) {
      debugPrint('[位置上报] 网络不可用，无法手动上报');
      return false;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: AppTheme.duration15s,
      );

      await _service.reportLocation(position.latitude, position.longitude);
      debugPrint('[位置上报] 手动上报成功');
      return true;
    } catch (e) {
      debugPrint('[位置上报] 手动上报失败: $e');
      return false;
    }
  }

  /// 获取连续失败次数（可用于外部监控）
  int get consecutiveFailures => _consecutiveFailures;

  /// 释放资源（安全网：确保 Timer 和 StreamSubscription 被取消）
  void dispose() {
    stop();
  }
}

/// 位置上报服务 Provider
final locationReporterServiceProvider = Provider<LocationReporterService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  final connectivityService = ref.read(connectivityServiceProvider);
  final offlineQueue = ref.read(offlineQueueServiceProvider);
  final service = LocationReporterService(LocationService(dio), connectivityService, offlineQueue);
  ref.onDispose(() => service.dispose());
  return service;
});