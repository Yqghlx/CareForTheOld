import '../../../core/router/route_paths.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/extensions/api_error_extension.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/extensions/date_format_extension.dart';
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(ApiEndpoints.authRegister, data: {
        'phoneNumber': _phoneController.text,
        'password': _passwordController.text,
        'realName': _nameController.text,
        'role': _selectedRole == UserRole.elder ? 0 : 1,
        'birthDate': _selectedBirthDate != null
            ? _selectedBirthDate!.toDateString()
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
        context.go(RoutePaths.elderHome);
      } else {
        context.go(RoutePaths.childHome);
      }
    } on DioException catch (e) {
      final msg = e.toDisplayMessage(fallback: '注册失败，请检查输入信息');
      if (mounted) {
        context.showErrorSnackBar(msg);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.paddingAll24,
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
                        color: AppTheme.grey600,
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
                    if (picked != null && mounted) {
                      setState(() => _selectedBirthDate = picked);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: '出生日期（选填）',
                        prefixIcon: const Icon(Icons.cake),
                        suffixIcon: _selectedBirthDate != null
                            ? const Icon(Icons.check_circle, color: AppTheme.successColor)
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
                AppTheme.spacer24,

                // 角色选择
                const Text('请选择您的身份:', style: AppTheme.textBody16),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<UserRole>(
                        title: const Text('老人'),
                        subtitle: const Text('记录健康、查看用药提醒'),
                        value: UserRole.elder,
                        // ignore: deprecated_member_use - Flutter 3.32+ 推荐使用 RadioGroup，但 RadioListTile 仍可工作
                        groupValue: _selectedRole,
                        // ignore: deprecated_member_use
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
                        // ignore: deprecated_member_use
                        groupValue: _selectedRole,
                        // ignore: deprecated_member_use
                        onChanged: (value) {
                          setState(() => _selectedRole = value!);
                        },
                      ),
                    ),
                  ],
                ),
                AppTheme.spacer32,

                // 注册按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('注册', style: AppTheme.textBody18),
                  ),
                ),
                const SizedBox(height: 16),

                // 返回登录
                TextButton(
                  onPressed: () => context.go(RoutePaths.login),
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