import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/elder/pages/elder_home_page.dart';
import '../../features/elder/pages/health_record_page.dart';
import '../../features/elder/pages/health_trend_page.dart';
import '../../features/elder/pages/medication_page.dart';
import '../../features/child/pages/elder_health_trend_page.dart';
import '../../features/child/pages/child_home_page.dart';
import '../../features/child/pages/family_member_page.dart';
import '../../features/child/pages/elder_health_page.dart';
import '../../features/child/pages/elder_location_page.dart';
import '../../features/child/pages/emergency_page.dart';
import '../../features/shared/pages/settings_page.dart';
import '../../features/shared/pages/notification_page.dart';
import '../../features/shared/pages/neighbor_circle_page.dart';
import '../../features/shared/pages/neighbor_help_page.dart';
import '../../features/shared/pages/neighbor_help_rating_page.dart';
import '../../features/shared/pages/trust_ranking_page.dart';
import '../../shared/providers/auth_provider.dart';
import 'page_transitions.dart';
import 'route_paths.dart';

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
const _publicRoutes = [RoutePaths.login, RoutePaths.register];

/// 应用路由 Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(_authListenableProvider);

  return GoRouter(
    initialLocation: RoutePaths.login,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.isAuthenticated;
      final currentPath = state.matchedLocation;

      // 判断当前路径是否为公开路由
      final isPublicRoute = _publicRoutes.contains(currentPath);

      // 未登录访问受保护路由 → 重定向到登录页
      if (!isAuth && !isPublicRoute) {
        return RoutePaths.login;
      }

      // 已登录访问登录/注册页 → 根据角色跳转首页
      if (isAuth && isPublicRoute) {
        return authState.isElder ? RoutePaths.elderHome : RoutePaths.childHome;
      }

      return null;
    },
    routes: [
      // 认证路由
      GoRoute(
        path: RoutePaths.login,
        pageBuilder: (context, state) => FadePageTransition(child: const LoginPage()),
      ),
      GoRoute(
        path: RoutePaths.register,
        pageBuilder: (context, state) => SlidePageTransition(child: const RegisterPage()),
      ),

      // 老人端路由
      GoRoute(
        path: RoutePaths.elderHome,
        builder: (context, state) => const ElderHomePage(),
      ),
      GoRoute(
        path: RoutePaths.elderHealth,
        pageBuilder: (context, state) => SlidePageTransition(child: const HealthRecordPage()),
      ),
      GoRoute(
        path: RoutePaths.elderHealthTrend,
        pageBuilder: (context, state) => SlidePageTransition(child: const HealthTrendPage()),
      ),
      GoRoute(
        path: RoutePaths.elderMedication,
        pageBuilder: (context, state) => SlidePageTransition(child: const MedicationPage()),
      ),
      GoRoute(
        path: RoutePaths.elderFamily,
        pageBuilder: (context, state) => SlidePageTransition(child: const FamilyMemberPage()),
      ),

      // 子女端路由
      GoRoute(
        path: RoutePaths.childHome,
        builder: (context, state) => const ChildHomePage(),
      ),
      GoRoute(
        path: RoutePaths.childFamily,
        pageBuilder: (context, state) => SlidePageTransition(child: const FamilyMemberPage()),
      ),
      GoRoute(
        path: RoutePaths.childElderHealthPattern,
        pageBuilder: (context, state) {
          final elderId = state.pathParameters['elderId']!;
          return SlidePageTransition(child: ElderHealthPage(elderId: elderId));
        },
      ),
      GoRoute(
        path: RoutePaths.childElderHealthTrendPattern,
        pageBuilder: (context, state) {
          final elderId = state.pathParameters['elderId']!;
          final elderName = state.uri.queryParameters['name'] ?? '老人';
          return SlidePageTransition(
            child: ElderHealthTrendPage(elderId: elderId, elderName: elderName),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.childElderLocationPattern,
        pageBuilder: (context, state) {
          final elderId = state.pathParameters['elderId']!;
          return SlidePageTransition(child: ElderLocationPage(elderId: elderId));
        },
      ),
      GoRoute(
        path: RoutePaths.childEmergency,
        pageBuilder: (context, state) => SlidePageTransition(child: const EmergencyPage()),
      ),

      // 通用路由
      GoRoute(
        path: RoutePaths.settings,
        pageBuilder: (context, state) => FadePageTransition(child: const SettingsPage()),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        pageBuilder: (context, state) => FadePageTransition(child: const NotificationPage()),
      ),
      GoRoute(
        path: RoutePaths.neighborCircle,
        pageBuilder: (context, state) => SlidePageTransition(child: const NeighborCirclePage()),
      ),
      GoRoute(
        path: RoutePaths.neighborHelp,
        pageBuilder: (context, state) => SlidePageTransition(child: const NeighborHelpPage()),
      ),
      GoRoute(
        path: RoutePaths.neighborHelpRatePattern,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return SlidePageTransition(child: NeighborHelpRatingPage(requestId: id));
        },
      ),
      GoRoute(
        path: RoutePaths.trustRankingPattern,
        pageBuilder: (context, state) {
          final circleId = state.pathParameters['circleId']!;
          return SlidePageTransition(child: TrustRankingPage(circleId: circleId));
        },
      ),
    ],
  );
});
