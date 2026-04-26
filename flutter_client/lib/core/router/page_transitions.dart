import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// 淡入过渡动画（适合同级页面切换：通知、设置等）
///
/// 动画时长 300ms，适老化设计柔和过渡。
class FadePageTransition extends CustomTransitionPage {
  FadePageTransition({required super.child})
      : super(
          transitionDuration: AppTheme.duration300ms,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}

/// 滑动过渡动画（适合详情页进入：健康详情、用药详情、围栏管理等）
///
/// 从右侧滑入，300ms，easeOut 曲线确保入页自然减速。
class SlidePageTransition extends CustomTransitionPage {
  SlidePageTransition({required super.child})
      : super(
          transitionDuration: AppTheme.duration300ms,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            );
          },
        );
}
