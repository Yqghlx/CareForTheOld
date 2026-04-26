import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 统一空状态组件 — 替代各页面手写的空状态展示
///
/// 设计规范：图标 64px、主标题 18px 灰色、副标题 14px 浅灰色。
/// 所有列表页面的空状态统一使用此组件，保持视觉一致性。
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.grey400),
            AppTheme.spacer16,
            Text(
              title,
              style: const TextStyle(fontSize: 18, color: AppTheme.grey500),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppTheme.spacer8,
              Text(
                subtitle!,
                style: TextStyle(fontSize: 14, color: AppTheme.grey500),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              AppTheme.spacer20,
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 统一错误状态组件 — 替代各页面手写的错误展示
///
/// 自动将技术性错误信息转为用户友好的提示，
/// 并提供"重试"按钮让用户主动恢复。
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// 将技术错误信息转为用户友好提示
  static String friendlyMessage(String? error) {
    if (error == null) return AppTheme.msgLoadFailed;
    if (error.contains('SocketException') || error.contains('网络')) {
      return AppTheme.msgNetworkError;
    }
    if (error.contains('401')) return AppTheme.msgSessionExpired;
    if (error.contains('403')) return '没有权限执行此操作';
    if (error.contains('404')) return AppTheme.msgNotFound;
    if (error.contains('500') || error.contains('502') || error.contains('503')) {
      return AppTheme.msgServerError;
    }
    // 默认截取前 50 字符，避免向用户暴露长堆栈信息
    if (error.length > 50) return AppTheme.msgLoadFailed;
    return error;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.error),
            AppTheme.spacer12,
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            AppTheme.spacer16,
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 骨架屏基础闪烁动画
///
/// 使用 AnimatedContainer 实现循环 shimmer 效果（不依赖第三方包）。
/// 适老化设计：动画时长 400ms，颜色变化柔和。
class SkeletonLoader extends StatefulWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.duration400ms,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppTheme.grey300,
                AppTheme.grey200,
                AppTheme.grey300,
              ],
              stops: [0.0, _animation.value, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 列表项骨架 — 圆形头像 + 两行文本
///
/// 用于通知列表、紧急呼叫列表等列表类页面的加载占位。
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonLoader(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AppTheme.grey300, radius: 24),
        title: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 160,
            height: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.grey300,
                borderRadius: AppTheme.radius4,
              ),
            ),
          ),
        ),
        subtitle: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 100,
            height: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.grey300,
                borderRadius: AppTheme.radius4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片骨架 — 矩形块 + 文本行
///
/// 用于健康数据卡片、用药计划卡片等卡片类页面的加载占位。
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonLoader(
      child: Card(
        margin: AppTheme.marginBottom12,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusL,
        ),
        child: Padding(
          padding: AppTheme.paddingAll16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                height: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.grey300,
                    borderRadius: AppTheme.radius4,
                  ),
                ),
              ),
              AppTheme.spacer12,
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.grey300,
                          borderRadius: AppTheme.radiusXS,
                        ),
                      ),
                    ),
                  ),
                  AppTheme.hSpacer12,
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.grey300,
                          borderRadius: AppTheme.radiusXS,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
