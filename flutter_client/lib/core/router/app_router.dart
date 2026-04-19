import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../shared/providers/auth_provider.dart';

/// 认证状态变化监听器，用于触发 GoRouter 重新执行 redirect
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final _authListenableProvider = Provider<_AuthStateListenable>((ref) {
  return _AuthStateListenable(ref);
});

/// 公开路由（无需认证）
const _publicRoutes = ['/login', '/register'];

/// 应用路由 Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(_authListenableProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.isAuthenticated;
      final currentPath = state.matchedLocation;

      // 判断当前路径是否为公开路由
      final isPublicRoute = _publicRoutes.contains(currentPath);

      // 未登录访问受保护路由 → 重定向到登录页
      if (!isAuth && !isPublicRoute) {
        return '/login';
      }

      // 已登录访问登录/注册页 → 根据角色跳转首页
      if (isAuth && isPublicRoute) {
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
});
