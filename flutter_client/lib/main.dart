import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/app_logger.dart';
import 'core/services/fcm_service.dart';
import 'core/services/offline_queue_service.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/services/emergency_alert_service.dart';
import 'features/shared/services/local_notification_service.dart';
import 'features/shared/pages/emergency_alert_page.dart';

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

  // 初始化日志系统（生产环境仅输出 WARNING及以上级别）
  AppLogger.init();

  // 初始化 Firebase（FCM 推送通知）
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase 初始化成功');
  } catch (e) {
    debugPrint('Firebase 初始化失败（可能是模拟器无 Google Play Services）: $e');
  }

  // 初始化本地通知
  await LocalNotificationService.initialize();

  // 初始化 Hive 本地数据库（离线队列使用）
  final appDir = await getApplicationDocumentsDirectory();
  Hive.init(appDir.path);

  // 初始化 Sentry 错误监控
  // DSN 从环境变量或编译配置注入，未配置时自动禁用
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  // 全局 Flutter 框架错误捕获（Widget 构建异常、布局溢出等）
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (sentryDsn.isNotEmpty) {
      Sentry.captureException(details.exception, stackTrace: details.stack);
    }
  };

  // 全局平台错误捕获（异步未捕获异常）
  PlatformDispatcher.instance.onError = (error, stack) {
    if (sentryDsn.isNotEmpty) {
      Sentry.captureException(error, stackTrace: stack);
    }
    return true;
  };

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        // 采样率：开发环境 100%，生产环境 20%
        final env = const String.fromEnvironment('APP_ENV', defaultValue: 'development');
        options.tracesSampleRate = env == 'production' ? 0.2 : 1.0;
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
class CareForTheOldApp extends ConsumerStatefulWidget {
  const CareForTheOldApp({super.key});

  @override
  ConsumerState<CareForTheOldApp> createState() => _CareForTheOldAppState();
}

class _CareForTheOldAppState extends ConsumerState<CareForTheOldApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 初始化离线队列（网络恢复后自动上传）
      ref.read(offlineQueueServiceProvider).init();

      // 初始化 FCM 服务
      _initFcm();

      // 监听紧急警报状态变化，自动弹出全屏警报页面
      EmergencyAlertService.instance.onAlertChanged = () {
        if (EmergencyAlertService.instance.isAlerting && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const EmergencyAlertPage(),
              fullscreenDialog: true,
            ),
          );
        }
      };
    });
  }

  /// 初始化 FCM 服务
  Future<void> _initFcm() async {
    try {
      await ref.read(fcmServiceProvider).initialize();
    } catch (e) {
      debugPrint('FCM 初始化异常: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '关爱老人',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      scaffoldMessengerKey: scaffoldMessengerKey,
      // 限制字体缩放上限 1.5 倍，防止老人设置过大系统字体导致布局崩坏
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
          ),
          child: child!,
        );
      },
    );
  }
}
