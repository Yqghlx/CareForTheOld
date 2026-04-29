import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 统计卡片组件 - 用于显示数值统计
class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppTheme.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusL,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusL,
        child: Container(
          padding: AppTheme.paddingAll16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: AppTheme.radiusS,
                ),
                child: Icon(icon, size: AppTheme.iconSize2xl, color: color),
              ),
              AppTheme.spacer12,
              Text(
                title,
                style: AppTheme.textSecondary16,
              ),
              AppTheme.spacer4,
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                AppTheme.spacer4,
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 信息卡片组件 - 用于显示带标题和操作的内容卡片
class InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Gradient? gradient;

  const InfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.onTap,
    this.backgroundColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Padding(
      padding: AppTheme.paddingAll20,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            AppTheme.hSpacer16,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.textTitle,
                ),
                if (subtitle != null) ...[
                  AppTheme.spacer4,
                  Text(
                    subtitle!,
                    style: AppTheme.textSecondary14,
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );

    // 如果有渐变背景，使用 Container 包装
    if (gradient != null) {
      cardContent = Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppTheme.radiusL,
        ),
        child: cardContent,
      );
    }

    return Card(
      elevation: AppTheme.cardElevation,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusL,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusL,
        child: cardContent,
      ),
    );
  }
}

/// 状态标签组件 - 用于显示状态信息
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.paddingH12V6,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppTheme.radiusXS,
      ),
      child: Text(
        label,
        style: AppTheme.textBody16.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 渐变卡片组件 - 用于用户信息展示等
class GradientCard extends StatelessWidget {
  final Gradient gradient;
  final Widget child;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.gradient,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppTheme.cardElevationHigh,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusL,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusL,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: AppTheme.radiusL,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 带动画的快捷卡片 - 用于首页快捷操作
class AnimatedQuickCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const AnimatedQuickCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<AnimatedQuickCard> createState() => _AnimatedQuickCardState();
}

class _AnimatedQuickCardState extends State<AnimatedQuickCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.duration250ms,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title}，${widget.subtitle}',
      child: GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: RepaintBoundary(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Card(
          elevation: AppTheme.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusL,
          ),
          child: Container(
            padding: AppTheme.paddingAll12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: AppTheme.radiusM,
                  ),
                  child: Icon(widget.icon, size: AppTheme.iconSize2xl, color: widget.color),
                ),
                AppTheme.spacer8,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.title,
                    style: AppTheme.textHeading,
                    maxLines: 1,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.subtitle,
                    style: AppTheme.textCaptionSmall.copyWith(color: AppTheme.grey600),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
      ),
    );
  }
}