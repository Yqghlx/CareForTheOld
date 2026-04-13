import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../core/theme/app_theme.dart';
import 'health_record_page.dart';
import 'medication_page.dart';

/// 老人端首页
class ElderHomePage extends ConsumerStatefulWidget {
  const ElderHomePage({super.key});

  @override
  ConsumerState<ElderHomePage> createState() => _ElderHomePageState();
}

class _ElderHomePageState extends ConsumerState<ElderHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 老人端使用大字体主题
    final theme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.2),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('关爱老人'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsDialog(),
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: '健康',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication),
              label: '用药',
            ),
          ],
          selectedFontSize: 18,
          unselectedFontSize: 16,
          selectedItemColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 底部导航栏切换页面内容，不使用路由导航（避免 build 期间调用 setState）
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const HealthRecordPage();
      case 2:
        return const MedicationPage();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final authState = ref.watch(authProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户信息卡片 - 渐变背景
          GradientCard(
            gradient: AppTheme.warmGradient,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.user?.realName ?? '用户',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '今天感觉怎么样？',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 快捷操作
          const Text(
            '快捷操作',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              AnimatedQuickCard(
                icon: Icons.favorite,
                title: '记录健康',
                subtitle: '血压、血糖、心率',
                color: Colors.red,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              AnimatedQuickCard(
                icon: Icons.medication,
                title: '用药提醒',
                subtitle: '查看今日用药',
                color: Colors.blue,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              AnimatedQuickCard(
                icon: Icons.people,
                title: '家庭成员',
                subtitle: '查看家人信息',
                color: Colors.green,
                onTap: () => context.push('/elder/family'),
              ),
              AnimatedQuickCard(
                icon: Icons.settings,
                title: '设置',
                subtitle: '个人信息设置',
                color: Colors.grey,
                onTap: () => _showSettingsDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 设置对话框（登出）
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户: ${ref.read(authProvider).user?.realName ?? "未知"}'),
            const SizedBox(height: 8),
            Text('角色: ${ref.read(authProvider).user?.role.label ?? "未知"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.red, Colors.redAccent],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }
}