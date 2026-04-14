import 'package:go_router/go_router.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/elder/pages/elder_home_page.dart';
import '../../features/elder/pages/health_record_page.dart';
import '../../features/elder/pages/health_trend_page.dart';
import '../../features/elder/pages/medication_page.dart';
import '../../features/child/pages/child_home_page.dart';
import '../../features/child/pages/family_member_page.dart';
import '../../features/child/pages/elder_health_page.dart';
import '../../features/child/pages/elder_location_page.dart';
import '../../features/child/pages/emergency_page.dart';
import '../../features/shared/pages/settings_page.dart';
import '../../features/shared/pages/notification_page.dart';

/// 应用路由配置
final appRouter = GoRouter(
  initialLocation: '/login',
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
      path: '/elder/home',
      builder: (context, state) => const ElderHomePage(),
    ),
    GoRoute(
      path: '/elder/health',
      builder: (context, state) => const HealthRecordPage(),
    ),
    GoRoute(
      path: '/elder/health/trend',
      builder: (context, state) => const HealthTrendPage(),
    ),
    GoRoute(
      path: '/elder/medication',
      builder: (context, state) => const MedicationPage(),
    ),
    GoRoute(
      path: '/elder/family',
      builder: (context, state) => const FamilyMemberPage(),
    ),

    // 子女端路由
    GoRoute(
      path: '/child/home',
      builder: (context, state) => const ChildHomePage(),
    ),
    GoRoute(
      path: '/child/family',
      builder: (context, state) => const FamilyMemberPage(),
    ),
    GoRoute(
      path: '/child/elder/:elderId/health',
      builder: (context, state) {
        final elderId = state.pathParameters['elderId']!;
        return ElderHealthPage(elderId: elderId);
      },
    ),
    GoRoute(
      path: '/child/elder/:elderId/location',
      builder: (context, state) {
        final elderId = state.pathParameters['elderId']!;
        return ElderLocationPage(elderId: elderId);
      },
    ),
    GoRoute(
      path: '/child/emergency',
      builder: (context, state) => const EmergencyPage(),
    ),

    // 通用路由
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationPage(),
    ),
  ],
);