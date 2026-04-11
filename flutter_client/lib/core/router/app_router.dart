import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/elder/pages/elder_home_page.dart';
import '../../features/elder/pages/health_record_page.dart';
import '../../features/elder/pages/medication_page.dart';
import '../../features/child/pages/child_home_page.dart';
import '../../features/child/pages/family_member_page.dart';
import '../../features/child/pages/elder_health_page.dart';
import '../../shared/providers/auth_provider.dart';

/// 应用路由配置
final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final authState = ProviderScope.containerOf(context).read(authProvider);

    // 未登录时重定向到登录页
    if (!authState.isAuthenticated && state.matchedLocation != '/login' && state.matchedLocation != '/register') {
      return '/login';
    }

    // 已登录时根据角色重定向
    if (authState.isAuthenticated && state.matchedLocation == '/login') {
      return authState.isElder ? '/elder/home' : '/child/home';
    }

    return null;
  },
  routes: [
    // 认证路由
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    // 老人端路由
    GoRoute(
      path: '/elder',
      routes: [
        GoRoute(
          path: 'home',
          builder: (context, state) => const ElderHomePage(),
        ),
        GoRoute(
          path: 'health',
          builder: (context, state) => const HealthRecordPage(),
        ),
        GoRoute(
          path: 'medication',
          builder: (context, state) => const MedicationPage(),
        ),
      ],
    ),

    // 子女端路由
    GoRoute(
      path: '/child',
      routes: [
        GoRoute(
          path: 'home',
          builder: (context, state) => const ChildHomePage(),
        ),
        GoRoute(
          path: 'family',
          builder: (context, state) => const FamilyMemberPage(),
        ),
        GoRoute(
          path: 'elder/:elderId/health',
          builder: (context, state) {
            final elderId = state.pathParameters['elderId']!;
            return ElderHealthPage(elderId: elderId);
          },
        ),
      ],
    ),
  ],
);