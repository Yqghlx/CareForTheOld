import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// 应用统一日志封装
///
/// 开发环境输出所有级别日志，生产环境仅输出 WARNING及以上级别。
/// 使用方式：
/// - AppLogger.debug('调试信息') - 仅开发环境可见
/// - AppLogger.info('一般信息') - 仅开发环境可见
/// - AppLogger.warning('警告信息') - 开发和生产都可见
/// - AppLogger.error('错误信息') - 开发和生产都可见
class AppLogger {
  static final Logger _logger = Logger('CareForTheOld');

  /// 初始化日志系统
  ///
  /// 生产环境（kReleaseMode）仅记录 WARNING及以上级别。
  /// 开发环境记录所有级别并输出到控制台。
  static void init() {
    Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;

    Logger.root.onRecord.listen((record) {
      // 生产环境不输出低级别日志
      if (kReleaseMode && record.level < Level.WARNING) return;

      final prefix = '${record.level.name}: ${record.loggerName}:';
      debugPrint('$prefix ${record.message}');

      if (record.error != null) {
        debugPrint('$prefix Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        debugPrint('$prefix StackTrace: ${record.stackTrace}');
      }
    });
  }

  /// 调试日志（仅开发环境）
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.fine(message, error, stackTrace);
  }

  /// 信息日志（仅开发环境）
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info(message, error, stackTrace);
  }

  /// 警告日志（开发和生产环境）
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning(message, error, stackTrace);
  }

  /// 错误日志（开发和生产环境）
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }
}