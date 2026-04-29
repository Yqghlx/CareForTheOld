import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// BuildContext 的 SnackBar 扩展方法，简化调用
///
/// 用法：context.showSnackBar('操作成功');
///       context.showErrorSnackBar('加载失败');
extension SnackBarExtension on BuildContext {
  /// 适老化 SnackBar 时长（默认 4 秒，老人阅读更从容）
  static const _duration = AppTheme.duration4s;

  /// 显示普通 SnackBar（先清除已有的，防止堆叠）
  void showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: _duration),
    );
  }

  /// 显示成功 SnackBar（绿色背景）
  void showSuccessSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.successColor, duration: _duration),
    );
  }

  /// 显示错误 SnackBar（红色背景）
  void showErrorSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor, duration: _duration),
    );
  }

  /// 显示警告 SnackBar（黄色背景）
  void showWarningSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.warningColor, duration: _duration),
    );
  }
}
