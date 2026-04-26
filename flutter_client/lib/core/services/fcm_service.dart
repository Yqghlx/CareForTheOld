import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../features/shared/services/emergency_alert_service.dart';
import '../api/api_client.dart';
import '../constants/api_endpoints.dart';
import 'app_logger.dart';

/// FCM 后台消息处理入口（必须是顶层函数）
///
/// APP 在后台/终止状态时由 Flutter Engine 直接调用，
/// 不能访问任何 Isolate 内的对象（Provider、Singleton 等）。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 初始化 Firebase（后台 Isolate 需要独立初始化）
  await Firebase.initializeApp();
  AppLogger.debug('[FCM 后台] 收到消息: ${message.messageId}');
  // 后台消息由系统通知栏自动显示（FCM notification payload）
}

/// FCM 推送通知服务
///
/// 负责：
/// 1. 初始化 Firebase 并获取 FCM token
/// 2. 登录后将 token 注册到后端
/// 3. 前台消息处理（触发全屏紧急警报）
/// 4. 后台消息由系统通知栏处理
/// 5. Token 刷新时自动更新后端
class FcmService {
  final Ref _ref;
  final _log = Logger('FcmService');
  String? _currentToken;

  /// StreamSubscription 引用，用于 dispose 时取消订阅
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;

  FcmService(this._ref);

  /// 初始化 FCM 服务
  Future<void> initialize() async {
    try {
      // 注册后台消息处理器
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 请求通知权限（Android 13+）
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _log.warning('用户拒绝了通知权限');
        return;
      }

      // 获取 FCM token
      _currentToken = await messaging.getToken();
      _log.info('FCM token 已获取: ${_currentToken?.substring(0, 20)}...');

      // 监听 token 刷新
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(_onTokenRefresh);

      // 前台消息处理
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 通知点击（APP 从后台通过通知打开）
      _messageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      _log.info('FCM 服务初始化完成');
    } catch (e) {
      _log.warning('FCM 初始化失败（可能是模拟器无 Google Play Services）: $e');
    }
  }

  /// 将当前 FCM token 注册到后端（登录成功后调用）
  Future<void> registerTokenToBackend() async {
    if (_currentToken == null) {
      _log.warning('FCM token 为空，跳过注册');
      return;
    }

    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.dio.post(ApiEndpoints.deviceToken, data: {
        'token': _currentToken,
        'platform': 'android',
      });
      _log.info('FCM token 已注册到后端');
    } catch (e) {
      _log.warning('FCM token 注册失败: $e');
    }
  }

  /// 从后端清除 token（登出时调用）
  Future<void> unregisterTokenFromBackend() async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.dio.delete(ApiEndpoints.deviceToken);
      _log.info('FCM token 已从后端清除');
    } catch (e) {
      _log.warning('FCM token 清除失败: $e');
    }
  }

  /// Token 刷新时自动更新后端
  void _onTokenRefresh(String newToken) {
    _log.info('FCM token 已刷新');
    _currentToken = newToken;
    registerTokenToBackend();
  }

  /// 处理前台消息
  ///
  /// APP 在前台时收到 FCM 推送，根据 data.type 判断是否触发全屏警报。
  void _handleForegroundMessage(RemoteMessage message) {
    _log.info('收到前台 FCM 消息: ${message.messageId}');

    final data = message.data;
    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'emergency_call':
      case 'emergency_reminder':
        // 紧急呼叫 → 触发全屏警报
        EmergencyAlertService.instance.triggerAlert(
          callId: data['callId'] as String? ?? '',
          elderName: data['elderName'] as String? ?? '老人',
          elderId: data['elderId'] as String? ?? '',
          isReminder: type == 'emergency_reminder',
        );
        break;
      default:
        _log.fine('非紧急消息，忽略前台处理: $type');
    }
  }

  /// 处理通知点击（从后台打开 APP）
  void _handleMessageOpenedApp(RemoteMessage message) {
    _log.info('通过通知打开 APP: ${message.messageId}');

    final data = message.data;
    final type = data['type'] as String? ?? '';

    if (type == 'emergency_call' || type == 'emergency_reminder') {
      EmergencyAlertService.instance.triggerAlert(
        callId: data['callId'] as String? ?? '',
        elderName: data['elderName'] as String? ?? '老人',
        elderId: data['elderId'] as String? ?? '',
        isReminder: type == 'emergency_reminder',
      );
    }
  }

  /// 释放资源，取消所有 StreamSubscription
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedAppSubscription?.cancel();
    _log.info('FCM 服务资源已释放');
  }
}

/// FCM 服务 Provider
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
