import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:care_for_the_old_client/main.dart';

void main() {
  testWidgets('App 启动烟雾测试', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CareForTheOldApp()));

    // 验证登录页面标题显示
    expect(find.text('关爱老人'), findsOneWidget);
  });
}
