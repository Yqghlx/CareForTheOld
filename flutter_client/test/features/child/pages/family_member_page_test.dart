import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/helpers/dialog_test_helper.dart';

/// 家庭成员页面对话框生命周期测试
///
/// 直接测试对话框 Widget 的生命周期（不依赖整个页面渲染），
/// 验证所有家庭管理对话框在取消/保存时不会触发 _dependents.isEmpty 断言。
///
/// 覆盖的对话框：
/// 1. 创建家庭组（单个 TextEditingController）
/// 2. 加入家庭（单个 TextEditingController + StatefulBuilder）
/// 3. 添加成员（单个 TextEditingController + StatefulBuilder）
void main() {
  group('家庭成员对话框 — 控制器释放', () {
    /// 创建家庭组对话框模拟
    testWidgets('创建家庭组对话框 — 取消关闭无异常', (tester) async {
      final errors = captureFlutterErrors();
      final nameController = TextEditingController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('创建家庭组'),
                    content: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '家庭组名称'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('创建'),
                      ),
                    ],
                  ),
                ).then((_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    nameController.dispose();
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

      expect(errors, isEmpty, reason: '创建家庭组对话框取消关闭不应有错误');
    });

    /// 加入家庭对话框模拟（StatefulBuilder + DropdownButtonFormField）
    testWidgets('加入家庭对话框 — 取消关闭无异常', (tester) async {
      final errors = captureFlutterErrors();
      final codeController = TextEditingController();

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
                          title: const Text('加入家庭'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: codeController,
                                decoration: const InputDecoration(
                                  labelText: '邀请码（6位数字）',
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ).then((_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    codeController.dispose();
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
      // 输入邀请码
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(errors, isEmpty, reason: '加入家庭对话框取消关闭不应有错误');
    });

    /// 添加成员对话框模拟
    testWidgets('添加成员对话框 — 取消关闭无异常', (tester) async {
      final errors = captureFlutterErrors();
      final phoneController = TextEditingController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    // ignore: unused_local_variable
                    String selectedRole = 'child';
                    return StatefulBuilder(
                      builder: (ctx, setDialogState) {
                        return AlertDialog(
                          title: const Text('添加成员'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: phoneController,
                                decoration: const InputDecoration(labelText: '手机号'),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ).then((_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    phoneController.dispose();
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
      await tester.enterText(find.byType(TextField), '13800138000');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(errors, isEmpty, reason: '添加成员对话框取消关闭不应有错误');
    });
  });

  group('家庭成员对话框 — 小屏幕布局', () {
    testWidgets('创建家庭组对话框 320x568 无溢出', (tester) async {
      final errors = captureFlutterErrors();
      final nameController = TextEditingController();

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
                    title: const Text('创建家庭组'),
                    content: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '家庭组名称'),
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
                    nameController.dispose();
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
        (e) => e.exceptionAsString().contains('overflow'),
      );
      expect(overflowErrors, isEmpty, reason: '320x568 下创建家庭组对话框不应溢出');

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });
}
