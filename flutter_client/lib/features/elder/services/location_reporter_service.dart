import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../services/location_service.dart';

/// 位置上报服务（老人端后台定时上报）
class LocationReporterService {
  final LocationService _service;
  Timer? _timer;
  bool _isRunning = false;
  static const Duration _reportInterval = Duration(minutes: 5);

  LocationReporterService(this._service);

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 启动位置上报
  Future<bool> start() async {
    if (_isRunning) return true;

    // 检查定位开关设置
    final prefs = await SharedPreferences.getInstance();
    final locationEnabled = prefs.getBool('location_enabled') ?? true;
    if (!locationEnabled) {
      debugPrint('定位上报已关闭');
      return false;
    }

    // 检查并请求定位权限
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('定位服务未开启');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('定位权限被拒绝');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('定位权限永久被拒绝');
      return false;
    }

    // 立即上报一次位置
    await _reportLocation();

    // 启动定时器
    _timer = Timer.periodic(_reportInterval, (_) => _reportLocationIfEnabled());
    _isRunning = true;
    debugPrint('位置上报服务已启动');
    return true;
  }

  /// 停止位置上报
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('位置上报服务已停止');
  }

  /// 检查并上报位置（根据设置决定是否上报）
  Future<void> _reportLocationIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final locationEnabled = prefs.getBool('location_enabled') ?? true;
    if (!locationEnabled) {
      debugPrint('定位上报已关闭，跳过上报');
      return;
    }
    await _reportLocation();
  }

  /// 上报位置
  Future<void> _reportLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint('获取位置: ${position.latitude}, ${position.longitude}');
      await _service.reportLocation(position.latitude, position.longitude);
      debugPrint('位置上报成功');
    } catch (e) {
      debugPrint('位置上报失败: $e');
    }
  }

  /// 手动上报一次位置
  Future<bool> reportNow() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      await _service.reportLocation(position.latitude, position.longitude);
      return true;
    } catch (e) {
      debugPrint('手动位置上报失败: $e');
      return false;
    }
  }
}

/// 位置上报服务 Provider
final locationReporterServiceProvider = Provider<LocationReporterService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return LocationReporterService(LocationService(dio));
});