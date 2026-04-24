import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// DioException 的扩展方法，用于从后端响应中提取错误信息
///
/// 用法：final message = dioException.toDisplayMessage();
///       final message = dioException.toDisplayMessage(fallback: '操作失败');
extension DioExceptionExtension on DioException {
  /// 从 DioException 中提取后端返回的用户可读错误信息
  ///
  /// 提取优先级：
  /// 1. 后端返回的 validation errors（字段级错误，合并为换行分隔的字符串）
  /// 2. 后端返回的 message 字段
  /// 3. 网络类型的友好提示（连接超时、无网络等）
  /// 4. [fallback] 参数指定的默认信息
  String toDisplayMessage({String fallback = '操作失败，请稍后重试'}) {
    try {
      final data = response?.data;
      if (data is Map<String, dynamic>) {
        // 优先提取 validation errors（字段级校验错误）
        final errors = data['errors'];
        if (errors is Map) {
          return errors.values
              .expand((v) => v is List ? v : [v])
              .join('\n');
        }
        // 其次提取通用 message
        if (data['message'] != null) {
          return data['message'] as String;
        }
      }
    } catch (_) {
      // 解析响应数据失败，使用默认错误信息
      debugPrint('解析错误响应失败: ${response?.statusCode}');
    }
    switch (type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return '无法连接服务器，请检查网络';
      default:
        return fallback;
    }
  }
}
