import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/family.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/family_provider.dart';

/// 家庭成员管理页面（子女端可管理，老人端只可查看）
class FamilyMemberPage extends ConsumerStatefulWidget {
  const FamilyMemberPage({super.key});

  @override
  ConsumerState<FamilyMemberPage> createState() => _FamilyMemberPageState();
}

class _FamilyMemberPageState extends ConsumerState<FamilyMemberPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(familyProvider.notifier).loadFamily();
    });
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final authState = ref.watch(authProvider);
    final isElder = authState.user?.role.isElder ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('家庭成员')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 家庭信息卡片
            _buildFamilyCard(familyState, isElder),
            const SizedBox(height: 24),

            // 成员列表标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('家庭成员',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                // 只有子女端可以添加成员
                if (familyState.family != null && !isElder)
                  TextButton.icon(
                    onPressed: () => _showAddMemberDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('添加成员'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 成员列表
            Expanded(child: _buildContent(familyState, isElder)),
          ],
        ),
      ),
    );
  }

  /// 家庭信息卡片
  Widget _buildFamilyCard(FamilyState state, bool isElder) {
    if (state.family == null && !state.isLoading) {
      // 没有家庭组
      if (isElder) {
        // 老人端：显示提示信息
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.home, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('您还未加入家庭组',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('请让子女添加您到家庭',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        );
      }
      // 子女端：显示创建按钮
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.home, size: 48, color: Color(0xFFE86B4A)),
              const SizedBox(height: 12),
              const Text('您还没有加入家庭组',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreateFamilyDialog(),
                icon: const Icon(Icons.add),
                label: const Text('创建家庭组'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.home, size: 32, color: Color(0xFFE86B4A)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.family?.familyName ?? '加载中...',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '共 ${state.members.length} 位成员',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 内容区域
  Widget _buildContent(FamilyState state, bool isElder) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.family == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: ${state.error}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(familyProvider.notifier).loadFamily(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.members.isEmpty) {
      return const Center(
        child: Text('暂无家庭成员', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: state.members.length,
      itemBuilder: (context, index) {
        final member = state.members[index];
        return _buildMemberItem(member, isElder);
      },
    );
  }

  /// 成员列表项
  Widget _buildMemberItem(FamilyMember member, bool isElder) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              member.role.isElder ? Colors.orange : Colors.blue,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(member.realName),
        subtitle: Text('${member.role.label} · ${member.relation}'),
        // 老人端不显示移除按钮
        trailing: isElder ? null : IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          onPressed: () => _confirmRemove(member),
        ),
      ),
    );
  }

  /// 创建家庭组对话框
  void _showCreateFamilyDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建家庭组'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '家庭组名称',
            hintText: '如：张家',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final success = await ref
                  .read(familyProvider.notifier)
                  .createFamily(name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '创建成功' : '创建失败')),
                );
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  /// 添加成员对话框
  void _showAddMemberDialog() {
    final phoneController = TextEditingController();
    final relationController = TextEditingController();
    String selectedRole = 'child';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('添加家庭成员'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: '角色'),
                    items: const [
                      DropdownMenuItem(value: 'child', child: Text('子女')),
                      DropdownMenuItem(value: 'elder', child: Text('老人')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: relationController,
                    decoration: const InputDecoration(
                      labelText: '称呼（如：妈妈、爸爸）',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final phone = phoneController.text.trim();
                    final relation = relationController.text.trim();
                    if (phone.isEmpty || relation.isEmpty) return;
                    Navigator.pop(ctx);
                    final success = await ref
                        .read(familyProvider.notifier)
                        .addMember(
                          phoneNumber: phone,
                          role: selectedRole == 'elder'
                              ? UserRole.elder
                              : UserRole.child,
                          relation: relation,
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? '添加成功' : '添加失败')),
                      );
                    }
                  },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 确认移除成员
  void _confirmRemove(FamilyMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要移除 ${member.realName} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(familyProvider.notifier)
                  .removeMember(member.userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '已移除' : '移除失败')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }
}
