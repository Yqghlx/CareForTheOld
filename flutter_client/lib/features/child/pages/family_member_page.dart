import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/family.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';
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
      body: RefreshIndicator(
        onRefresh: () => ref.read(familyProvider.notifier).loadFamily(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 家庭信息/邀请码卡片
              _buildFamilyCard(familyState, isElder),
              const SizedBox(height: 24),

              // 成员列表
              if (familyState.family != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('家庭成员',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (!isElder)
                      TextButton.icon(
                        onPressed: () => _showAddMemberDialog(),
                        icon: const Icon(Icons.person_add, size: 20),
                        label: const Text('添加成员'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMemberList(familyState, isElder),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 家庭信息卡片
  Widget _buildFamilyCard(FamilyState state, bool isElder) {
    // 未加入家庭
    if (state.family == null && !state.isLoading) {
      if (isElder) {
        return _buildJoinFamilyCard();
      }
      return _buildCreateFamilyCard();
    }

    final family = state.family;
    if (family == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 家庭名称卡片
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: AppTheme.warmGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.home, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            family.familyName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '共 ${family.members.length} 位成员',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 子女端显示邀请码
                if (!isElder) ...[
                  const SizedBox(height: 20),
                  _buildInviteCodeSection(family),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 邀请码区域（子女端显示）
  Widget _buildInviteCodeSection(FamilyGroup family) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '邀请码',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  family.inviteCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),
              // 复制按钮
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: family.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('邀请码已复制'),
                      backgroundColor: AppTheme.successColor,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: '复制邀请码',
              ),
              // 刷新按钮
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () async {
                  final success = await ref.read(familyProvider.notifier).refreshInviteCode();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '邀请码已刷新' : '刷新失败'),
                        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                    );
                  }
                },
                tooltip: '刷新邀请码',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '将邀请码分享给家人，即可加入家庭',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 创建家庭卡片（子女端）
  Widget _buildCreateFamilyCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.home, size: 40, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            const Text('您还没有创建家庭组', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('创建家庭组后，可以邀请家人加入', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            PrimaryButton(
              text: '创建家庭组',
              onPressed: () => _showCreateFamilyDialog(),
            ),
          ],
        ),
      ),
    );
  }

  /// 加入家庭卡片（老人端）
  Widget _buildJoinFamilyCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.group_add, size: 40, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text('您还未加入家庭组', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('请让子女分享邀请码给您', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            PrimaryButton(
              text: '输入邀请码加入',
              onPressed: () => _showJoinFamilyDialog(),
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.deepOrange],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 成员列表
  Widget _buildMemberList(FamilyState state, bool isElder) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final members = state.members;
    if (members.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('暂无家庭成员', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    return Column(
      children: members.map((member) => _buildMemberCard(member, isElder)).toList(),
    );
  }

  /// 成员卡片
  Widget _buildMemberCard(FamilyMember member, bool isElder) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 头像
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (member.role.isElder ? Colors.orange : Colors.blue).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                member.role.isElder ? Icons.elderly : Icons.person,
                color: member.role.isElder ? Colors.orange : Colors.blue,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.realName.isEmpty ? '未设置姓名' : member.realName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (member.role.isElder ? Colors.orange : Colors.blue).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          member.role.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: member.role.isElder ? Colors.orange : Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        member.relation,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 移除按钮（子女端可操作）
            if (!isElder)
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade300),
                onPressed: () => _confirmRemove(member),
                tooltip: '移除成员',
              ),
          ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.home, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Text('创建家庭组'),
          ],
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: '家庭组名称',
            hintText: '如：张家',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          PrimaryButton(
            text: '创建',
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final success = await ref.read(familyProvider.notifier).createFamily(name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '创建成功！邀请码已生成' : '创建失败'),
                    backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 加入家庭对话框（老人端）
  void _showJoinFamilyDialog() {
    final codeController = TextEditingController();
    String? selectedRelation;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vpn_key, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  const Text('加入家庭'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: '邀请码（6位数字）',
                      prefixIcon: const Icon(Icons.vpn_key),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRelation,
                    decoration: InputDecoration(
                      labelText: '您与创建者的关系',
                      prefixIcon: const Icon(Icons.people),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: '爸爸', child: Text('爸爸')),
                      DropdownMenuItem(value: '妈妈', child: Text('妈妈')),
                      DropdownMenuItem(value: '爷爷', child: Text('爷爷')),
                      DropdownMenuItem(value: '奶奶', child: Text('奶奶')),
                      DropdownMenuItem(value: '外公', child: Text('外公')),
                      DropdownMenuItem(value: '外婆', child: Text('外婆')),
                      DropdownMenuItem(value: '其他', child: Text('其他')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedRelation = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                PrimaryButton(
                  text: '加入',
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                  ),
                  onPressed: () async {
                    final code = codeController.text.trim();
                    if (code.length != 6 || selectedRelation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('请输入6位邀请码并选择关系'),
                          backgroundColor: AppTheme.warningColor,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await ref.read(familyProvider.notifier).joinFamily(
                      inviteCode: code,
                      relation: selectedRelation!,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '加入家庭成功！' : '加入失败，请检查邀请码'),
                          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 添加成员对话框（子女端）
  void _showAddMemberDialog() {
    final phoneController = TextEditingController();
    String selectedRole = 'child';
    String? selectedRelation;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // 根据角色动态生成关系选项
            final relationItems = selectedRole == 'elder'
                ? const [
                    DropdownMenuItem(value: '爷爷', child: Text('爷爷')),
                    DropdownMenuItem(value: '奶奶', child: Text('奶奶')),
                    DropdownMenuItem(value: '外公', child: Text('外公')),
                    DropdownMenuItem(value: '外婆', child: Text('外婆')),
                    DropdownMenuItem(value: '爸爸', child: Text('爸爸')),
                    DropdownMenuItem(value: '妈妈', child: Text('妈妈')),
                    DropdownMenuItem(value: '其他', child: Text('其他')),
                  ]
                : const [
                    DropdownMenuItem(value: '儿子', child: Text('儿子')),
                    DropdownMenuItem(value: '女儿', child: Text('女儿')),
                    DropdownMenuItem(value: '其他', child: Text('其他')),
                  ];
            // 角色切换时重置关系选项
            if (selectedRelation != null &&
                !relationItems.any((item) => item.value == selectedRelation)) {
              selectedRelation = null;
            }
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text('添加成员'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: '手机号',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: '角色',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'child', child: Text('子女')),
                      DropdownMenuItem(value: 'elder', child: Text('老人')),
                    ],
                    onChanged: (v) => setDialogState(() {
                      selectedRole = v!;
                      selectedRelation = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRelation,
                    decoration: InputDecoration(
                      labelText: '称呼',
                      prefixIcon: const Icon(Icons.people),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: relationItems,
                    onChanged: (v) => setDialogState(() => selectedRelation = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                PrimaryButton(
                  text: '添加',
                  onPressed: () async {
                    final phone = phoneController.text.trim();
                    if (phone.isEmpty || selectedRelation == null) return;
                    // 前端手机号格式校验（11 位中国手机号）
                    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('请输入正确的手机号格式'),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await ref.read(familyProvider.notifier).addMember(
                      phoneNumber: phone,
                      role: selectedRole == 'elder' ? UserRole.elder : UserRole.child,
                      relation: selectedRelation!,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '添加成功' : '添加失败'),
                          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      );
                    }
                  },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('移除成员'),
        content: Text('确定要将 ${member.realName} 移出家庭组吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          PrimaryButton(
            text: '移除',
            gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(familyProvider.notifier).removeMember(member.userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '已移除' : '移除失败'),
                    backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
