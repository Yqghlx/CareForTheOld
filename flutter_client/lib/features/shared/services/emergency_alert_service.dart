import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// 紧急警报服务（全局单例）
///
/// 管理全屏紧急警报的状态：震动、铃声、警报触发/停止。
/// 被 FCM 前台消息和 SignalR 紧急通知共同调用。
class EmergencyAlertService {
  EmergencyAlertService._();
  static final EmergencyAlertService instance = EmergencyAlertService._();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// 警报是否正在触发
  bool _isAlerting = false;
  bool get isAlerting => _isAlerting;

  /// 当前警报信息
  String _callId = '';
  String _elderName = '';
  String _elderId = '';
  bool _isReminder = false;

  String get callId => _callId;
  String get elderName => _elderName;
  String get elderId => _elderId;
  bool get isReminder => _isReminder;

  /// 警报状态变化回调（UI 监听此回调刷新全屏警报页面）
  VoidCallback? onAlertChanged;

  /// 触发紧急警报
  Future<void> triggerAlert({
    required String callId,
    required String elderName,
    required String elderId,
    bool isReminder = false,
  }) async {
    if (_isAlerting) return; // 避免重复触发

    _callId = callId;
    _elderName = elderName;
    _elderId = elderId;
    _isReminder = isReminder;
    _isAlerting = true;

    // 启动震动
    _startVibration();

    // 启动警报铃声
    await _startAlarm();

    // 通知 UI 刷新
    onAlertChanged?.call();

    debugPrint('紧急警报已触发: $elderName (呼叫ID: $callId)');
  }

  /// 停止警报（用户点击响应按钮后调用）
  Future<void> stopAlert() async {
    _isAlerting = false;

    // 停止震动
    await _stopVibration();

    // 停止铃声
    await _stopAlarm();

    // 通知 UI 刷新
    onAlertChanged?.call();

    debugPrint('紧急警报已停止');
  }

  /// 启动循环震动
  Future<void> _startVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      // 循环震动：震动 500ms，暂停 500ms，重复
      await Vibration.vibrate(pattern: [500, 500, 500, 500], repeat: 0);
    } catch (e) {
      debugPrint('震动启动失败: $e');
    }
  }

  /// 停止震动
  Future<void> _stopVibration() async {
    try {
      Vibration.cancel();
    } catch (e) {
      debugPrint('震动停止失败: $e');
    }
  }

  /// 启动警报铃声（循环播放系统默认警报声）
  Future<void> _startAlarm() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(UrlSource(
        'https://actions.google.com/sounds/v1/alarms/beep_full.ogg',
      ));
    } catch (e) {
      // 网络不可用时使用系统默认通知音
      debugPrint('在线铃声加载失败，使用系统默认音: $e');
      try {
        await _audioPlayer.play(DeviceFileSource(''));
      } catch (_) {}
    }
  }

  /// 停止警报铃声
  Future<void> _stopAlarm() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('铃声停止失败: $e');
    }
  }
}
