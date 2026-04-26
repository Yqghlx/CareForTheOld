import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../api/api_client.dart';
import '../constants/api_endpoints.dart';
import 'connectivity_service.dart';

/// 离线队列中的待上传项
class OfflineQueueItem {
  final String id;
  final String type; // 'location', 'health', 'medication'
  final Map<String, dynamic> data;
  final DateTime createdAt;

  OfflineQueueItem({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) =>
      OfflineQueueItem(
        id: json['id'] as String,
        type: json['type'] as String,
        data: json['data'] as Map<String, dynamic>,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// 离线队列服务
///
/// 当网络不可用时，将位置上报和健康录入数据存入本地 Hive 数据库，
/// 网络恢复后自动批量上传，确保数据不丢失。
class OfflineQueueService {
  static const _boxName = 'offline_queue';
  static const _maxQueueSize = 100; // 防止队列无限增长

  final Dio _dio;
  final ConnectivityService _connectivityService;
  Box<String>? _box;
  StreamSubscription<bool>? _networkSubscription;
  bool _isFlushing = false;

  OfflineQueueService(this._dio, this._connectivityService);

  /// 初始化 Hive Box
  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);

    // 监听网络恢复，自动触发上传
    _networkSubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('[离线队列] 网络恢复，开始上传队列');
        flush();
      }
    });

    // 启动时如果在线，尝试上传队列
    if (_connectivityService.isOnline && _box!.isNotEmpty) {
      flush();
    }

    debugPrint('[离线队列] 初始化完成，队列中 ${_box!.length} 条待上传');
  }

  /// 入队：离线时保存数据
  Future<void> enqueue(String type, Map<String, dynamic> data) async {
    if (_box == null) return;

    final item = OfflineQueueItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    // 队列满时移除最旧的项
    if (_box!.length >= _maxQueueSize) {
      final oldestKey = _box!.keys.first;
      await _box!.delete(oldestKey);
    }

    await _box!.put(item.id, jsonEncode(item.toJson()));
    debugPrint('[离线队列] 入队: type=$type, 队列长度=${_box!.length}');
  }

  /// 批量上传队列中的所有数据
  Future<void> flush() async {
    if (_box == null || _isFlushing || _box!.isEmpty) return;
    _isFlushing = true;

    try {
      final keys = _box!.keys.toList();
      var successCount = 0;
      var failCount = 0;

      for (final key in keys) {
        final raw = _box!.get(key);
        if (raw == null) continue;

        final item = OfflineQueueItem.fromJson(jsonDecode(raw));
        final success = await _uploadItem(item);

        if (success) {
          await _box!.delete(key);
          successCount++;
        } else {
          failCount++;
        }
      }

      if (successCount > 0 || failCount > 0) {
        debugPrint(
            '[离线队列] 上传完成: 成功=$successCount, 失败=$failCount, 剩余=${_box!.length}');
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// 上传单条数据
  Future<bool> _uploadItem(OfflineQueueItem item) async {
    try {
      switch (item.type) {
        case 'location':
          await _dio.post(ApiEndpoints.location, data: item.data);
          return true;
        case 'health':
          await _dio.post(ApiEndpoints.health, data: item.data);
          return true;
        case 'medication':
          await _dio.post(ApiEndpoints.medicationLogs, data: item.data);
          return true;
        default:
          debugPrint('[离线队列] 未知类型: ${item.type}，跳过');
          return true; // 未知类型直接移除
      }
    } catch (e) {
      debugPrint('[离线队列] 上传失败: type=${item.type}, error=$e');
      return false;
    }
  }

  /// 当前队列长度
  int get queueLength => _box?.length ?? 0;

  /// 释放资源
  void dispose() {
    _networkSubscription?.cancel();
    _box?.close();
  }
}

/// 离线队列服务 Provider
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  final connectivityService = ref.read(connectivityServiceProvider);
  final service = OfflineQueueService(dio, connectivityService);
  ref.onDispose(() => service.dispose());
  return service;
});
