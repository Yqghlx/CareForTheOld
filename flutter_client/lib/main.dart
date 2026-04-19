import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地通知
  await LocalNotificationService.initialize();

  runApp(const ProviderScope(child: CareForTheOldApp()));
}

/// 应用入口
class CareForTheOldApp extends ConsumerWidget {
  const CareForTheOldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '关爱老人',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: const Locale('zh', 'CN'),
    );
  }
}
