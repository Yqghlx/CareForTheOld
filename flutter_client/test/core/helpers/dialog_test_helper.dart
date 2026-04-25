import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 捕获 Flutter 框架断言错误
///
/// 在测试期间捕获 `FlutterError.onError` 中的错误，
/// 用于检测 `_dependents.isEmpty` 等断言失败。
/// 测试结束后自动恢复原始错误处理器。
///
/// 返回一个列表，测试中可通过检查列表是否为空来判断是否有错误。
List<FlutterErrorDetails> captureFlutterErrors() {
  final errors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
    // 同时报告给原始处理器，避免吞掉其他错误
    originalOnError?.call(details);
  };
  // 在测试结束时恢复
  addTearDown(() => FlutterError.onError = originalOnError);
  return errors;
}

/// 验证对话框在指定屏幕尺寸下无布局溢出
///
/// [tester] Widget 测试器
/// [size] 模拟的屏幕物理尺寸
/// [widget] 需要渲染的 Widget
/// [dialogTrigger] 触发对话框打开的元素查找器
Future<void> testNoOverflowAtSize({
  required WidgetTester tester,
  required Size size,
  required Widget widget,
  required Finder dialogTrigger,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final errors = captureFlutterErrors();

  await tester.pumpWidget(widget);
  await tester.tap(dialogTrigger);
  await tester.pump();
  // 执行多帧让布局完全计算
  await tester.pump();
  await tester.pump();

  // 检查是否有溢出相关错误
  final overflowErrors = errors.where(
    (e) => e.exceptionAsString().contains('overflow') ||
        e.exceptionAsString().contains('RenderFlex overflowed'),
  );
  expect(overflowErrors, isEmpty, reason: '${size.width}x${size.height} 屏幕下存在布局溢出');
}
