import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';
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
  String? _errorMessage;

  // Logo 呼吸动画
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

  /// 从 DioException 中提取后端返回的错误信息
  String _extractErrorMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'] as String;
      }
    } catch (_) {}
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return '无法连接服务器，请检查网络';
      default:
        return '手机号或密码错误';
    }
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      debugPrint('开始登录请求... 手机号: ${phoneController.text}');
      final response = await apiClient.dio.post('/auth/login', data: {
        'phoneNumber': phoneController.text,
        'password': passwordController.text,
      });
      debugPrint('登录响应状态: ${response.statusCode}');
      debugPrint('登录响应数据: ${response.data}');

      final data = response.data['data'];
      final user = User.fromJson(data['user']);
      debugPrint('用户信息: ${user.realName}, 角色: ${user.role}');

      // 等待 login 完成，确保 token 已更新后再跳转
      await ref.read(authProvider.notifier).login(
        user: user,
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );

      if (user.role.isElder) {
        context.go('/elder/home');
      } else {
        context.go('/child/home');
      }
    } on DioException catch (e) {
      debugPrint('登录异常: $e');
      final serverMessage = _extractErrorMessage(e);
      if (mounted) setState(() => _errorMessage = serverMessage);
    } catch (e) {
      debugPrint('登录未知异常: $e');
      if (mounted) setState(() => _errorMessage = '网络连接失败，请检查网络设置');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 渐变背景
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF5F0), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                        borderRadius: BorderRadius.circular(24),
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
                  const SizedBox(height: 24),
                  // 标题
                  const Text(
                    '关爱老人',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '健康监测 · 用药提醒',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 手机号输入
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 18),
                      validator: FormValidators.phone,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 密码输入
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                      decoration: const InputDecoration(
                        labelText: '密码',
                        prefixIcon: Icon(Icons.lock, color: AppTheme.primaryColor),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      obscureText: true,
                      style: const TextStyle(fontSize: 18),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 错误信息提示
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: AppTheme.errorColor, fontSize: 14),
                            ),
                          ),
                          if (_errorMessage!.contains('手机号或密码错误') ||
                              _errorMessage!.contains('错误'))
                            TextButton(
                              onPressed: () => context.go('/register'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                '去注册',
                                style: TextStyle(color: AppTheme.primaryColor, fontSize: 14),
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
                    onPressed: () => context.go('/register'),
                    child: Text(
                      '没有账号？点击注册',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                      ),
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