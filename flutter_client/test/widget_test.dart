import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:care_for_the_old_client/main.dart';

void main() {
  setUp(() async {
    // 初始化 Hive 内存模式（离线队列依赖）
    Hive.init('');
  });

  testWidgets('App 启动烟雾测试', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CareForTheOldApp()));
    await tester.pump();

    // 验证应用框架已加载
    expect(find.byType(CareForTheOldApp), findsOneWidget);
  });
}
