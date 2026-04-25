import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/helpers/dialog_test_helper.dart';

/// 对话框控制器释放生命周期测试
///
/// 验证 showDialog 中使用 TextEditingController 时，
/// 关闭对话框（取消/返回）不会触发 Flutter 框架断言错误。
///
/// 此测试覆盖的 bug 模式：
/// - 在 showDialog().then() 中直接调用 controller.dispose()
/// - 对话框 Widget 树未完全卸载时，TextField 仍持有控制器引用
/// - 导致 ChangeNotifier.dispose() 的 _dependents.isEmpty 断言失败
void main() {
  group('对话框控制器释放模式', () {
    group('正确模式 — addPostFrameCallback 延迟释放', () {
      testWidgets('单个控制器：取消按钮关闭对话框无异常', (tester) async {
        final errors = captureFlutterErrors();
        final controller = TextEditingController();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: TextField(controller: controller),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ).then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller.dispose();
                    });
                  });
                },
                child: const Text('打开对话框'),
              );
            }),
          ),
        ));

        await tester.tap(find.text('打开对话框'));
        await tester.pump();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(errors, isEmpty,
            reason: '使用 addPostFrameCallback 释放控制器不应有 Flutter 错误');
      });

      testWidgets('多个控制器：取消按钮关闭对话框无异常', (tester) async {
        final errors = captureFlutterErrors();
        final controller1 = TextEditingController();
        final controller2 = TextEditingController();
        final controller3 = TextEditingController();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: controller1),
                          TextField(controller: controller2),
                          TextField(controller: controller3),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ).then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller1.dispose();
                      controller2.dispose();
                      controller3.dispose();
                    });
                  });
                },
                child: const Text('打开对话框'),
              );
            }),
          ),
        ));

        await tester.tap(find.text('打开对话框'));
        await tester.pump();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(errors, isEmpty,
            reason: '多个控制器使用 addPostFrameCallback 释放不应有 Flutter 错误');
      });

      testWidgets('输入文字后取消关闭对话框无异常', (tester) async {
        final errors = captureFlutterErrors();
        final controller = TextEditingController();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: TextField(controller: controller),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ).then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller.dispose();
                    });
                  });
                },
                child: const Text('打开对话框'),
              );
            }),
          ),
        ));

        await tester.tap(find.text('打开对话框'));
        await tester.pump();
        // 输入文字，激活控制器与 TextField 的依赖关系
        await tester.enterText(find.byType(TextField), '测试文字');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(errors, isEmpty,
            reason: '输入文字后取消关闭对话框不应有 Flutter 错误');
      });
    });

    group('StatefulBuilder 对话框', () {
      testWidgets('StatefulBuilder 内的控制器取消关闭无异常', (tester) async {
        final errors = captureFlutterErrors();
        final controller = TextEditingController();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return StatefulBuilder(
                        builder: (ctx, setDialogState) {
                          return AlertDialog(
                            content: TextField(controller: controller),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('取消'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  // 模拟更新对话框状态
                                  setDialogState(() {});
                                },
                                child: const Text('刷新'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ).then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller.dispose();
                    });
                  });
                },
                child: const Text('打开对话框'),
              );
            }),
          ),
        ));

        await tester.tap(find.text('打开对话框'));
        await tester.pump();
        // 触发 setDialogState
        await tester.tap(find.text('刷新'));
        await tester.pump();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(errors, isEmpty,
            reason: 'StatefulBuilder 对话框关闭不应有 Flutter 错误');
      });
    });

    group('不同屏幕尺寸下的对话框布局', () {
      testWidgets('小屏幕 (320x568) 下对话框无溢出', (tester) async {
        final errors = captureFlutterErrors();
        final controller = TextEditingController();

        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 模拟正常范围提示
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '正常范围: 收缩压 90-140 / 舒张压 60-90 mmHg',
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(controller: controller),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ).then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller.dispose();
                    });
                  });
                },
                child: const Text('打开对话框'),
              );
            }),
          ),
        ));

        await tester.tap(find.text('打开对话框'));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // 检查溢出错误
        final overflowErrors = errors.where(
          (e) => e.exceptionAsString().contains('overflow') ||
              e.exceptionAsString().contains('RenderFlex'),
        );
        expect(overflowErrors, isEmpty,
            reason: '320x568 小屏幕下对话框不应有布局溢出');

        // 清理
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      });

      testWidgets('极窄屏幕 (280x568) 下对话框无溢出', (tester) async {
        final errors = captureFlutterErrors();
        final controller = TextEditingController();

        tester.view.physicalSize = const Size(280, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '正常范围: 收缩压 90-140 / 舒张压 60-90 mmHg',
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextField(controller: controller),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ).then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller.dispose();
                    });
                  });
                },
                child: const Text('打开对话框'),
              );
            }),
          ),
        ));

        await tester.tap(find.text('打开对话框'));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        final overflowErrors = errors.where(
          (e) => e.exceptionAsString().contains('overflow') ||
              e.exceptionAsString().contains('RenderFlex'),
        );
        expect(overflowErrors, isEmpty,
            reason: '280x568 极窄屏幕下对话框不应有布局溢出');

        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      });
    });
  });
}
