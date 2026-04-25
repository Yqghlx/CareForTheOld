import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/helpers/dialog_test_helper.dart';

/// 设置页面对话框生命周期测试
///
/// 覆盖的对话框：
/// 1. 修改姓名（单个 TextEditingController）
/// 2. 修改密码（三个 TextEditingController）
void main() {
  group('设置页面对话框 — 控制器释放', () {
    testWidgets('修改姓名对话框 — 取消关闭无异常', (tester) async {
      final errors = captureFlutterErrors();
      final nameController = TextEditingController(text: '张三');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('修改姓名'),
                    content: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '姓名'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('保存'),
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
      // 修改姓名
      await tester.enterText(find.byType(TextField), '李四');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(errors, isEmpty, reason: '修改姓名对话框取消关闭不应有错误');
    });

    testWidgets('修改密码对话框 — 三个控制器取消关闭无异常', (tester) async {
      final errors = captureFlutterErrors();
      final oldPasswordController = TextEditingController();
      final newPasswordController = TextEditingController();
      final confirmPasswordController = TextEditingController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('修改密码'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: oldPasswordController,
                          decoration: const InputDecoration(
                              labelText: '当前密码'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: newPasswordController,
                          decoration: const InputDecoration(
                              labelText: '新密码'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmPasswordController,
                          decoration: const InputDecoration(
                              labelText: '确认新密码'),
                          obscureText: true,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('修改'),
                      ),
                    ],
                  ),
                ).then((_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    oldPasswordController.dispose();
                    newPasswordController.dispose();
                    confirmPasswordController.dispose();
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
      // 填写三个密码框
      await tester.enterText(
          find.widgetWithText(TextField, '当前密码'), 'oldPass123');
      await tester.enterText(
          find.widgetWithText(TextField, '新密码'), 'newPass456');
      await tester.enterText(
          find.widgetWithText(TextField, '确认新密码'), 'newPass456');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(errors, isEmpty, reason: '修改密码对话框取消关闭不应有错误');
    });
  });
}
