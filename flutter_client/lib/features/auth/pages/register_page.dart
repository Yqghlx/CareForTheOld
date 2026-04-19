import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validators/form_validators.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/user_role.dart';

/// 注册页面
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  UserRole _selectedRole = UserRole.elder;
  DateTime? _selectedBirthDate;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// 从后端响应中提取验证错误信息
  String _extractErrorMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        // 优先提取 validation errors
        final errors = data['errors'];
        if (errors is Map) {
          return errors.values.expand((v) => v is List ? v : [v]).join('\n');
        }
        if (data['message'] != null) {
          return data['message'] as String;
        }
      }
    } catch (_) {}
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return '无法连接服务器，请检查网络';
      default:
        return '注册失败，请检查输入信息';
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post('/auth/register', data: {
        'phoneNumber': _phoneController.text,
        'password': _passwordController.text,
        'realName': _nameController.text,
        'role': _selectedRole == UserRole.elder ? 0 : 1,
        'birthDate': _selectedBirthDate != null
            ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
            : '2000-01-01', // 未选择时使用默认值
      });

      final data = response.data['data'];
      final user = User.fromJson(data['user']);

      // 等待 login 完成，确保 token 已更新后再跳转
      await ref.read(authProvider.notifier).login(
        user: user,
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );

      // 根据角色跳转
      if (!mounted) return;
      if (user.role.isElder) {
        context.go('/elder/home');
      } else {
        context.go('/child/home');
      }
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('注册失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 手机号
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: FormValidators.phone,
                ),
                const SizedBox(height: 16),

                // 密码
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock),
                    helperText: '至少8位，需包含字母和数字',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: FormValidators.password,
                ),
                const SizedBox(height: 16),

                // 姓名
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '姓名',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: FormValidators.name,
                ),
                const SizedBox(height: 16),

                // 出生日期
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedBirthDate ?? DateTime(1960, 1, 1),
                      firstDate: DateTime(1920, 1, 1),
                      lastDate: now,
                      locale: const Locale('zh', 'CN'),
                    );
                    if (picked != null) {
                      setState(() => _selectedBirthDate = picked);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: '出生日期（选填）',
                        prefixIcon: const Icon(Icons.cake),
                        suffixIcon: _selectedBirthDate != null
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        hintText: '点击选择出生日期',
                      ),
                      controller: TextEditingController(
                        text: _selectedBirthDate != null
                            ? '${_selectedBirthDate!.year}年${_selectedBirthDate!.month}月${_selectedBirthDate!.day}日'
                            : '',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 角色选择
                const Text('请选择您的身份:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<UserRole>(
                        title: const Text('老人'),
                        subtitle: const Text('记录健康、查看用药提醒'),
                        value: UserRole.elder,
                        groupValue: _selectedRole,
                        onChanged: (value) {
                          setState(() => _selectedRole = value!);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<UserRole>(
                        title: const Text('子女'),
                        subtitle: const Text('查看老人健康、管理用药计划'),
                        value: UserRole.child,
                        groupValue: _selectedRole,
                        onChanged: (value) {
                          setState(() => _selectedRole = value!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // 注册按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('注册', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 16),

                // 返回登录
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('已有账号？点击登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}