import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/services/local_notification_service.dart';

/// 全局 ScaffoldMessenger Key，用于在无 Context 场景下显示 SnackBar
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 全局 SnackBar 提示工具
void showGlobalSnackBar(String message, {Color? backgroundColor}) {
  final state = scaffoldMessengerKey.currentState;
  if (state == null) return;
  state.clearSnackBars();
  state.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地通知
  await LocalNotificationService.initialize();

  // 初始化 Sentry 错误监控
  // DSN 从环境变量或编译配置注入，未配置时自动禁用
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        // 采样率：开发环境 100%，生产环境 20%
        options.tracesSampleRate = 1.0;
        // 上报环境
        options.environment = const String.fromEnvironment('APP_ENV', defaultValue: 'development');
        // 启用用户交互面包屑（按钮点击等）
        options.enableUserInteractionBreadcrumbs = true;
      },
      appRunner: () => runApp(const ProviderScope(child: CareForTheOldApp())),
    );
  } else {
    // 未配置 DSN 时直接启动，不集成 Sentry
    runApp(const ProviderScope(child: CareForTheOldApp()));
  }
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
      scaffoldMessengerKey: scaffoldMessengerKey,
    );
  }
}
