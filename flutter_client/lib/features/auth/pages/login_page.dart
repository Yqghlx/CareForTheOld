import '../../../core/router/route_paths.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/api_error_extension.dart';
import '../../../core/validators/form_validators.dart';

/// 登录页面
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Logo 呼吸动画
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      duration: AppTheme.duration1500ms,
      vsync: this,
    );
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOut,
      ),
    );
    _breathController.repeat(reverse: true);
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(ApiEndpoints.authLogin, data: {
        'phoneNumber': phoneController.text,
        'password': passwordController.text,
      });

      final data = response.data['data'];
      final user = User.fromJson(data['user']);

      // 等待 login 完成，确保 token 已更新后再跳转
      await ref.read(authProvider.notifier).login(
        user: user,
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );

      if (!mounted) return;
      if (user.role.isElder) {
        context.go(RoutePaths.elderHome);
      } else {
        context.go(RoutePaths.childHome);
      }
    } on DioException catch (e) {
      debugPrint('登录异常: $e');
      final serverMessage = e.toDisplayMessage(fallback: '手机号或密码错误');
      if (mounted) setState(() => _errorMessage = serverMessage);
    } catch (e) {
      debugPrint('登录未知异常: $e');
      if (mounted) setState(() => _errorMessage = AppTheme.msgNetworkError);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 渐变背景
        decoration: const BoxDecoration(
          gradient: AppTheme.warmBackgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: AppTheme.paddingAll24,
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Logo 呼吸动画
                  ScaleTransition(
                    scale: _breathAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppTheme.warmGradient,
                        borderRadius: AppTheme.radius2XL,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  AppTheme.spacer24,
                  // 标题
                  const Text(
                    '关爱老人',
                    style: AppTheme.textLogoTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '健康监测 · 用药提醒',
                    style: AppTheme.textSecondary16,
                  ),
                  const SizedBox(height: 48),

                  // 手机号输入
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.radiusS,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: '手机号',
                        prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
                        border: InputBorder.none,
                        contentPadding: AppTheme.paddingAll16,
                      ),
                      keyboardType: TextInputType.phone,
                      style: AppTheme.textBody18,
                      validator: FormValidators.phone,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 密码输入
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.radiusS,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryColor),
                        border: InputBorder.none,
                        contentPadding: AppTheme.paddingAll16,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.grey600,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                        ),
                      ),
                      obscureText: _obscurePassword,
                      style: AppTheme.textBody18,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                    ),
                  ),
                  AppTheme.spacer32,

                  // 错误信息提示
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: AppTheme.paddingH16V12,
                      margin: AppTheme.marginBottom16,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: AppTheme.radiusXS,
                        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTheme.textError14,
                            ),
                          ),
                          if (_errorMessage!.contains('手机号或密码错误') ||
                              _errorMessage!.contains('错误'))
                            TextButton(
                              onPressed: () => context.go(RoutePaths.register),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                '去注册',
                                style: AppTheme.textLink14,
                              ),
                            ),
                        ],
                      ),
                    ),

                  // 渐变登录按钮
                  PrimaryButton(
                    text: '登录',
                    onPressed: login,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 16),

                  // 注册链接
                  TextButton(
                    onPressed: () => context.go(RoutePaths.register),
                    child: Text(
                      '没有账号？点击注册',
                      style: AppTheme.textSecondary16.copyWith(color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}