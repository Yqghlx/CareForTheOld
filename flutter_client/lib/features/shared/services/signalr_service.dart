import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../shared/providers/emergency_provider.dart';
import 'local_notification_service.dart';

/// SignalR 连接服务
class SignalRService {
  HubConnection? _hubConnection;
  final Ref _ref;

  /// 心跳定时器（每 60 秒发送一次心跳）
  Timer? _heartbeatTimer;

  /// 从 AppConfig 读取 SignalR Hub URL
  static String get _hubUrl => AppConfig.current.signalrBaseUrl;

  SignalRService(this._ref);

  /// 是否已连接
  bool get isConnected =>
      _hubConnection?.state == HubConnectionState.Connected;

  /// 连接 SignalR Hub
  Future<void> connect() async {
    if (_hubConnection != null && isConnected) return;

    final token = _ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('未登录，跳过 SignalR 连接');
      return;
    }

    debugPrint('正在连接 SignalR Hub...');

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            requestTimeout: 10000,
          ),
        )
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .configureLogging(Logger('SignalR'))
        .build();

    // 监听服务器推送的通知
    _hubConnection!.on('ReceiveNotification', _handleNotification);

    // 连接关闭回调
    _hubConnection!.onclose(({error}) {
      debugPrint('SignalR 连接关闭: $error');
    });

    // 重连成功回调
    _hubConnection!.onreconnected(({connectionId}) {
      debugPrint('SignalR 重连成功: $connectionId');
    });

    // 重连中回调
    _hubConnection!.onreconnecting(({error}) {
      debugPrint('SignalR 正在重连: $error');
    });

    try {
      await _hubConnection!.start();
      debugPrint('SignalR 连接成功');
      _startHeartbeat();
    } catch (e) {
      debugPrint('SignalR 连接失败: $e');
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _hubConnection = null;
      debugPrint('SignalR 已断开连接');
    }
  }

  /// 处理接收到的通知
  void _handleNotification(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    try {
      // SignalR 传入参数：第一个是 type，第二个是 data
      final type = arguments[0]?.toString() ?? '';
      dynamic data = arguments.length > 1 ? arguments[1] : null;

      // data 可能是 Map 或 JSON 字符串
      Map<String, dynamic> notificationData;
      if (data is String) {
        notificationData = jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map) {
        notificationData = Map<String, dynamic>.from(data);
      } else {
        notificationData = {};
      }

      final title = notificationData['Title']?.toString() ?? '通知';
      final content = notificationData['Content']?.toString() ?? '';

      debugPrint('收到通知: [$type] $title - $content');

      // 根据通知类型处理
      switch (type) {
        case 'MedicationReminder':
        case 'MedicationReminderUrgent':
          _showMedicationReminder(title, content);
          break;
        case 'MedicationReminderFamily':
          _showMedicationReminderFamily(title, content);
          break;
        case 'MedicationMissed':
          // 老人未服药告警（高优先级通知）
          LocalNotificationService.showNotification(
            id: 3,
            title: title,
            body: content,
          );
          break;
        case 'EmergencyCall':
          // 紧急呼叫（最高优先级通知），同时刷新紧急呼叫列表
          LocalNotificationService.showNotification(
            id: 4,
            title: title,
            body: content,
          );
          _ref.invalidate(emergencyProvider);
          break;
        case 'EmergencyCallReminder':
          // 紧急呼叫二次提醒（最高优先级）
          LocalNotificationService.showNotification(
            id: 5,
            title: title,
            body: content,
          );
          _ref.invalidate(emergencyProvider);
          break;
        case 'GeoFenceAlert':
          // 电子围栏告警（老人离开/进入围栏）
          LocalNotificationService.showNotification(
            id: 6,
            title: title,
            body: content,
          );
          break;
        case 'HealthAlert':
          // 健康数据异常告警
          LocalNotificationService.showNotification(
            id: 7,
            title: title,
            body: content,
          );
          break;
        case 'HeartbeatAlert':
          // 心跳超时告警（老人设备离线）
          LocalNotificationService.showNotification(
            id: 8,
            title: title,
            body: content,
          );
          break;
        default:
          _showGeneralNotification(title, content);
      }
    } catch (e) {
      debugPrint('处理通知失败: $e');
    }
  }

  /// 显示用药提醒通知
  void _showMedicationReminder(String title, String content) {
    LocalNotificationService.showNotification(
      id: 1,
      title: title,
      body: content,
    );
  }

  /// 显示家庭用药提醒通知
  void _showMedicationReminderFamily(String title, String content) {
    LocalNotificationService.showNotification(
      id: 2,
      title: title,
      body: content,
    );
  }

  /// 显示通用通知
  void _showGeneralNotification(String title, String content) {
    LocalNotificationService.showNotification(
      id: 0,
      title: title,
      body: content,
    );
  }

  /// 启动心跳定时器（每 60 秒发送一次心跳，保持后端感知在线状态）
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_hubConnection != null && isConnected) {
        try {
          await _hubConnection!.invoke('Heartbeat');
          debugPrint('[心跳] 已发送');
        } catch (e) {
          debugPrint('[心跳] 发送失败: $e');
        }
      }
    });
  }
}

/// SignalR 服务 Provider
final signalrServiceProvider = Provider<SignalRService>((ref) {
  final service = SignalRService(ref);
  // Provider 销毁时自动断开连接，防止内存泄漏
  ref.onDispose(() => service.disconnect());
  return service;
});
