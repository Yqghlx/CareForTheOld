import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 显示确认对话框，返回用户是否确认
///
/// 返回 `true` 表示用户点击了确认按钮，`false` 或 `null` 表示取消。
///
/// 用法：
/// ```dart
/// final confirmed = await showConfirmDialog(
///   context,
///   title: '确认删除',
///   message: '确定删除该记录吗？此操作不可恢复。',
///   confirmText: '删除',
/// );
/// if (confirmed != true) return;
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = AppTheme.msgConfirm,
  String cancelText = AppTheme.msgCancel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          child: Text(confirmText),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}
