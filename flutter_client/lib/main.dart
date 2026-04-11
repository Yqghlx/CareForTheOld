import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: CareForTheOldApp()));
}

/// 应用入口
class CareForTheOldApp extends StatelessWidget {
  const CareForTheOldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '关爱老人',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      locale: const Locale('zh', 'CN'),
    );
  }
}