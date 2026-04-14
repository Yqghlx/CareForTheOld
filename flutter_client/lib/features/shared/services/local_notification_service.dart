import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 本地通知服务
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 通知渠道 ID
  static const String _channelId = 'care_for_the_old';
  static const String _channelName = '关爱老人通知';
  static const String _channelDescription = '用药提醒、紧急呼叫等通知';

  /// 初始化本地通知
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 请求 Android 通知权限（Android 13+）
    await _requestPermissions();

    _initialized = true;
    debugPrint('本地通知服务已初始化');
  }

  /// 请求通知权限
  static Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 显示通知
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
    debugPrint('显示通知: $title - $body');
  }

  /// 通知点击回调
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('通知点击: ${response.payload}');
    // 后续可扩展：根据 payload 跳转到对应页面
  }

  /// 取消指定通知
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// 取消所有通知
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

/// 本地通知服务 Provider
final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});
