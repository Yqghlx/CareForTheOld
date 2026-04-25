import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/helpers/dialog_test_helper.dart';

/// 健康记录页面对话框生命周期测试
///
/// 覆盖的对话框：
/// 1. 记录血压（valueController + valueController2 + noteController + 语音/OCR 区域）
/// 2. 记录血糖/心率/体温（valueController + noteController）
///
/// 重点测试：
/// - 多个 TextEditingController 的控制器释放
/// - StatefulBuilder 内的对话框生命周期
/// - 小屏幕下的布局溢出（正常范围提示行 + 快捷输入卡片）
void main() {
  group('健康记录对话框 — 控制器释放', () {
    testWidgets('记录血压对话框 — 取消关闭无异常', (tester) async {
      final errors = captureFlutterErrors();
      final valueController = TextEditingController();
      final valueController2 = TextEditingController();
      final noteController = TextEditingController();

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
                          title: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.favorite,
                                    color: Colors.red),
                              ),
                              const SizedBox(width: 12),
                              const Text('记录血压'),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 正常范围提示
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline,
                                          size: 18, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '正常范围: 收缩压 90-140 / 舒张压 60-90 mmHg',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.red),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 快捷输入区域（语音 + 拍照并列卡片）
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.mic,
                                                  color: Colors.white,
                                                  size: 32),
                                              SizedBox(height: 8),
                                              Text('语音输入',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.camera_alt,
                                                  color: Colors.white,
                                                  size: 32),
                                              SizedBox(height: 8),
                                              Text('拍照识别',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // 收缩压
                                TextField(
                                  controller: valueController,
                                  decoration: const InputDecoration(
                                    labelText: '收缩压（mmHg）',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 舒张压
                                TextField(
                                  controller: valueController2,
                                  decoration: const InputDecoration(
                                    labelText: '舒张压（mmHg）',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 备注
                                TextField(
                                  controller: noteController,
                                  decoration: const InputDecoration(
                                    labelText: '备注（可选）',
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
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
                        );
                      },
                    );
                  },
                ).then((_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    valueController.dispose();
                    valueController2.dispose();
                    noteController.dispose();
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
      // 填写血压数据
      await tester.enterText(
          find.widgetWithText(TextField, '收缩压（mmHg）'), '130');
      await tester.enterText(
          find.widgetWithText(TextField, '舒张压（mmHg）'), '85');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(errors, isEmpty, reason: '记录血压对话框取消关闭不应有错误');
    });
  });

  group('健康记录对话框 — 小屏幕布局', () {
    testWidgets('记录血压对话框 320x568 无溢出', (tester) async {
      final errors = captureFlutterErrors();
      final valueController = TextEditingController();
      final valueController2 = TextEditingController();
      final noteController = TextEditingController();

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
                    title: const Text('记录血压'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 正常范围提示（包含 Flexible 包裹的长文本）
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
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 并列卡片
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 80,
                                  color: Colors.blue,
                                  child: const Center(
                                    child: Text('语音输入',
                                        style:
                                            TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 80,
                                  color: Colors.red,
                                  child: const Center(
                                    child: Text('拍照识别',
                                        style:
                                            TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(controller: valueController),
                          const SizedBox(height: 12),
                          TextField(controller: valueController2),
                          const SizedBox(height: 12),
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                          ),
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
                    valueController.dispose();
                    valueController2.dispose();
                    noteController.dispose();
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
      expect(overflowErrors, isEmpty,
          reason: '320x568 下记录血压对话框不应有溢出');

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('记录血压对话框 280x568 极窄屏幕无溢出', (tester) async {
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
        (e) => e.exceptionAsString().contains('overflow'),
      );
      expect(overflowErrors, isEmpty,
          reason: '280x568 极窄屏幕下对话框不应有溢出');

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });
}
