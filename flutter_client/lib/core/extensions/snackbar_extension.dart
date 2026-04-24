import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// BuildContext 的 SnackBar 扩展方法，简化调用
///
/// 用法：context.showSnackBar('操作成功');
///       context.showErrorSnackBar('加载失败');
extension SnackBarExtension on BuildContext {
  /// 显示普通 SnackBar
  void showSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 显示成功 SnackBar（绿色背景）
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.successColor),
    );
  }

  /// 显示错误 SnackBar（红色背景）
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  /// 显示警告 SnackBar（黄色背景）
  void showWarningSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.warningColor),
    );
  }
}
