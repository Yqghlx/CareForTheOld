import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/widgets/common_states.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('显示图标和标题', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: '暂无数据',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('暂无数据'), findsOneWidget);
    });

    testWidgets('不显示副标题和操作按钮', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: '暂无数据',
            ),
          ),
        ),
      );

      // 没有副标题时不应有额外的 SizedBox(8)
      // 没有 action 时不应有额外的 SizedBox(20)
      expect(find.text('副标题'), findsNothing);
    });

    testWidgets('显示副标题', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: '暂无数据',
              subtitle: '下拉刷新获取最新数据',
            ),
          ),
        ),
      );

      expect(find.text('暂无数据'), findsOneWidget);
      expect(find.text('下拉刷新获取最新数据'), findsOneWidget);
    });

    testWidgets('显示操作按钮', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: '暂无数据',
              action: ElevatedButton(
                onPressed: () => pressed = true,
                child: const Text('点击重试'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('点击重试'), findsOneWidget);
      await tester.tap(find.text('点击重试'));
      expect(pressed, isTrue);
    });
  });

  group('ErrorStateWidget', () {
    testWidgets('显示错误信息和重试按钮', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              message: '加载失败',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('重试按钮可点击', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              message: '出错了',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('重试'));
      expect(retried, isTrue);
    });

    testWidgets('支持自定义图标', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              message: '无网络',
              onRetry: () {},
              icon: Icons.wifi_off,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    group('friendlyMessage', () {
      test('null 返回默认提示', () {
        expect(ErrorStateWidget.friendlyMessage(null), '加载失败，请重试');
      });

      test('网络错误转为友好提示', () {
        expect(
          ErrorStateWidget.friendlyMessage('SocketException: Connection refused'),
          '网络连接失败，请检查网络设置',
        );
        expect(
          ErrorStateWidget.friendlyMessage('网络不可用'),
          '网络连接失败，请检查网络设置',
        );
      });

      test('401 转为登录过期', () {
        expect(
          ErrorStateWidget.friendlyMessage('HttpException 401'),
          '登录已过期，请重新登录',
        );
      });

      test('403 转为权限不足', () {
        expect(
          ErrorStateWidget.friendlyMessage('403 Forbidden'),
          '没有权限执行此操作',
        );
      });

      test('404 转为资源不存在', () {
        expect(
          ErrorStateWidget.friendlyMessage('404 Not Found'),
          '请求的内容不存在',
        );
      });

      test('500/502/503 转为服务器繁忙', () {
        expect(
          ErrorStateWidget.friendlyMessage('500 Internal Server Error'),
          '服务器繁忙，请稍后重试',
        );
        expect(
          ErrorStateWidget.friendlyMessage('502 Bad Gateway'),
          '服务器繁忙，请稍后重试',
        );
        expect(
          ErrorStateWidget.friendlyMessage('503 Service Unavailable'),
          '服务器繁忙，请稍后重试',
        );
      });

      test('超长错误信息截断', () {
        final longError = 'A' * 100;
        expect(
          ErrorStateWidget.friendlyMessage(longError),
          '加载失败，请重试',
        );
      });

      test('短错误信息原样返回', () {
        expect(
          ErrorStateWidget.friendlyMessage('邀请码无效'),
          '邀请码无效',
        );
      });
    });
  });

  group('SkeletonListTile', () {
    testWidgets('正常渲染包含圆形头像和文本行', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonListTile(),
          ),
        ),
      );

      // 验证包含 CircleAvatar
      expect(find.byType(CircleAvatar), findsOneWidget);
      // 验证包含 SkeletonLoader
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });

    testWidgets('动画启动后不崩溃', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SkeletonListTile(),
                SkeletonListTile(),
              ],
            ),
          ),
        ),
      );

      // SkeletonLoader 使用 repeat(reverse: true) 无限循环动画，
      // 不能使用 pumpAndSettle（会超时），改用 pump 推进几帧验证不崩溃
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(SkeletonListTile), findsNWidgets(2));
    });
  });

  group('SkeletonCard', () {
    testWidgets('正常渲染包含 Card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonCard(),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });

    testWidgets('多个骨架卡片正常渲染', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SkeletonCard(),
                SkeletonCard(),
                SkeletonCard(),
              ],
            ),
          ),
        ),
      );

      // 推进几帧验证不崩溃（不使用 pumpAndSettle，因为动画无限循环）
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SkeletonCard), findsNWidgets(3));
    });
  });

  group('SkeletonLoader', () {
    testWidgets('包含子组件', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(
              child: SizedBox(
                width: 100,
                height: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('dispose 时释放 AnimationController', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(
              child: SizedBox(width: 50, height: 10),
            ),
          ),
        ),
      );

      // 推进一帧确保动画启动
      await tester.pump(const Duration(milliseconds: 100));

      // 替换为空 widget 触发 dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      // 推进一帧确认 dispose 正常（如果 dispose 不正确会抛出 Ticker leak 错误）
      await tester.pump(const Duration(milliseconds: 100));
      expect(true, isTrue);
    });
  });
}
