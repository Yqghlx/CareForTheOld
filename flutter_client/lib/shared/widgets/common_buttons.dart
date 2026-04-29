import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 按钮缩放动画 Mixin — 消除 PrimaryButton/SecondaryButton/PrimaryIconButton 的重复代码
mixin ButtonScaleAnimation {
  late final AnimationController scaleController;
  late final Animation<double> _scaleAnimation;

  bool get isButtonEnabled;

  void initScaleAnimation(TickerProvider vsync) {
    scaleController = AnimationController(
      duration: AppTheme.duration100ms,
      vsync: vsync,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: scaleController, curve: Curves.easeInOut),
    );
  }

  void disposeScaleAnimation() {
    scaleController.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (isButtonEnabled) scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    scaleController.reverse();
  }

  void _onTapCancel() {
    scaleController.reverse();
  }

  /// 构建带缩放动画的外壳
  Widget buildAnimated(VoidCallback? onTap, Widget child) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: child,
      ),
    );
  }
}

/// 主按钮组件 - 渐变背景、圆角、点击动画
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient,
    this.isLoading = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin, ButtonScaleAnimation {
  @override
  bool get isButtonEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    initScaleAnimation(this);
  }

  @override
  void dispose() {
    disposeScaleAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildAnimated(
      widget.isLoading ? null : widget.onPressed,
      Container(
        height: AppTheme.buttonHeight,
        decoration: BoxDecoration(
          gradient: widget.gradient ?? AppTheme.primaryGradient,
          borderRadius: AppTheme.radiusM,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppTheme.transparentColor,
          child: InkWell(
            borderRadius: AppTheme.radiusM,
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: AppTheme.iconSizeLg,
                      height: AppTheme.iconSizeLg,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cardColor),
                      ),
                    )
                  : Text(
                      widget.text,
                      style: AppTheme.textWhite18W600,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 次按钮组件 - 描边样式
class SecondaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color textColor;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.borderColor = AppTheme.primaryColor,
    this.textColor = AppTheme.primaryColor,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton>
    with SingleTickerProviderStateMixin, ButtonScaleAnimation {
  @override
  bool get isButtonEnabled => widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    initScaleAnimation(this);
  }

  @override
  void dispose() {
    disposeScaleAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildAnimated(
      widget.onPressed,
      Container(
        height: AppTheme.buttonHeight,
        decoration: BoxDecoration(
          border: Border.all(color: widget.borderColor, width: 2),
          borderRadius: AppTheme.radiusM,
        ),
        child: Material(
          color: AppTheme.transparentColor,
          child: InkWell(
            borderRadius: AppTheme.radiusM,
            onTap: widget.onPressed,
            child: Center(
              child: Text(
                widget.text,
                style: AppTheme.textWhite18W600.copyWith(
                  color: widget.textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 带图标的主按钮
class PrimaryIconButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final bool isLoading;

  const PrimaryIconButton({
    super.key,
    required this.text,
    required this.icon,
    this.onPressed,
    this.gradient,
    this.isLoading = false,
  });

  @override
  State<PrimaryIconButton> createState() => _PrimaryIconButtonState();
}

class _PrimaryIconButtonState extends State<PrimaryIconButton>
    with SingleTickerProviderStateMixin, ButtonScaleAnimation {
  @override
  bool get isButtonEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    initScaleAnimation(this);
  }

  @override
  void dispose() {
    disposeScaleAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildAnimated(
      widget.isLoading ? null : widget.onPressed,
      Container(
        height: AppTheme.buttonHeight,
        decoration: BoxDecoration(
          gradient: widget.gradient ?? AppTheme.primaryGradient,
          borderRadius: AppTheme.radiusM,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppTheme.transparentColor,
          child: InkWell(
            borderRadius: AppTheme.radiusM,
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: AppTheme.cardColor, size: AppTheme.iconSizeMd),
                AppTheme.hSpacer8,
                widget.isLoading
                    ? const SizedBox(
                        width: AppTheme.iconSizeMd,
                        height: AppTheme.iconSizeMd,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cardColor),
                        ),
                      )
                    : Text(
                        widget.text,
                        style: AppTheme.textWhite18W600,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
