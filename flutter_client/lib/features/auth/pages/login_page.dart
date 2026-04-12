import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/user.dart';

/// 登录页面
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

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

      ref.read(authProvider.notifier).login(
        user: user,
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );

      if (user.role.isElder) {
        context.go('/elder/home');
      } else {
        context.go('/child/home');
      }
    } catch (e, stackTrace) {
      debugPrint('登录异常: $e');
      debugPrint('堆栈: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                const Icon(
                  Icons.favorite,
                  size: 80,
                  color: Color(0xFFE86B4A),
                ),
                const SizedBox(height: 16),
                const Text(
                  '关爱老人',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE86B4A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '健康监测 · 用药提醒',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),

                // 手机号输入
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入手机号';
                    }
                    if (value.length != 11) {
                      return '手机号格式不正确';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 密码输入
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text('登录', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 16),

                // 注册链接
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('没有账号？点击注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
