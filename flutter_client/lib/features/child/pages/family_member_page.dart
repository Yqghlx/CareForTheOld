import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/family.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/extensions/snackbar_extension.dart';
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
    final isElder = authState.role?.isElder ?? authState.user?.role.isElder ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('家庭成员')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(familyProvider.notifier).loadFamily(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppTheme.paddingAll20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 家庭信息/邀请码卡片
              _buildFamilyCard(familyState, isElder),
              AppTheme.spacer24,

              // 待审批区域（子女端）
              if (!isElder && familyState.family != null) ...[
                _buildPendingSection(familyState),
                AppTheme.spacer16,
              ],

              // 成员列表
              if (familyState.family != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('家庭成员',
                        style: AppTheme.textTitle),
                    if (!isElder)
                      TextButton.icon(
                        onPressed: () => _showAddMemberDialog(),
                        icon: const Icon(Icons.person_add, size: AppTheme.iconSizeMd),
                        label: const Text('添加成员'),
                      ),
                  ],
                ),
                AppTheme.spacer12,
                _buildMemberList(familyState, isElder),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 待审批成员区域
  Widget _buildPendingSection(FamilyState state) {
    final pending = state.pendingMembers;
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('待审批',
                style: AppTheme.textTitle),
            AppTheme.hSpacer8,
            Container(
              padding: AppTheme.paddingH8V2,
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: AppTheme.radius10,
              ),
              child: Text(
                '${pending.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warningDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        AppTheme.spacer12,
        ...pending.map((member) => _buildPendingCard(member)),
      ],
    );
  }

  /// 待审批成员卡片
  Widget _buildPendingCard(FamilyMember member) {
    return Card(
      elevation: AppTheme.cardElevationLow,
      margin: AppTheme.marginBottom12,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
      child: Padding(
        padding: AppTheme.paddingAll16,
        child: Row(
          children: [
            // 头像
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radiusS,
              ),
              child: Icon(
                member.role.isElder ? Icons.elderly : Icons.person,
                color: AppTheme.warningColor,
                size: 26,
              ),
            ),
            AppTheme.hSpacer12,
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.realName.isEmpty ? '未设置姓名' : member.realName,
                    style: AppTheme.textHeading,
                  ),
                  AppTheme.spacer2,
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.1),
                          borderRadius: AppTheme.radius4,
                        ),
                        child: Text(
                          '待审批',
                          style: TextStyle(fontSize: 11, color: AppTheme.warningDark),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.relation,
                        style: AppTheme.textCaption13Grey600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 操作按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: AppTheme.successColor),
                  onPressed: () => _approveMember(member),
                  tooltip: '通过',
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: AppTheme.errorMedium),
                  onPressed: () => _rejectMember(member),
                  tooltip: '拒绝',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 审批通过
  Future<void> _approveMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
        title: const Text('审批确认'),
        content: Text('确定通过 ${member.realName} 的加入申请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppTheme.msgCancel),
          ),
          PrimaryButton(
            text: '通过',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await ref.read(familyProvider.notifier).approveMember(member.userId);
    if (mounted) {
      if (success) {
        context.showSuccessSnackBar('${AppTheme.msgFamilyApproved} ${member.realName} 的加入申请');
      } else {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    }
  }

  /// 拒绝申请
  Future<void> _rejectMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
        title: const Text('拒绝申请'),
        content: Text('确定拒绝 ${member.realName} 的加入申请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppTheme.msgCancel),
          ),
          PrimaryButton(
            text: '拒绝',
            gradient: const LinearGradient(colors: [AppTheme.errorColor, AppTheme.errorAccent]),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await ref.read(familyProvider.notifier).rejectMember(member.userId);
    if (mounted) {
      if (success) {
        context.showSuccessSnackBar(AppTheme.msgFamilyRejected);
      } else {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    }
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
            borderRadius: AppTheme.radiusXL,
          ),
          child: Padding(
            padding: AppTheme.paddingAll24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor.withValues(alpha: 0.2),
                        borderRadius: AppTheme.radiusS,
                      ),
                      child: const Icon(Icons.home, color: AppTheme.cardColor, size: 28),
                    ),
                    AppTheme.hSpacer16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            family.familyName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cardColor,
                            ),
                          ),
                          Text(
                            '共 ${family.members.length} 位成员',
                            style: TextStyle(
                              color: AppTheme.cardColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 子女端显示邀请码
                if (!isElder) ...[
                  AppTheme.spacer20,
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
      padding: AppTheme.paddingAll16,
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withValues(alpha: 0.15),
        borderRadius: AppTheme.radiusS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '邀请码',
            style: AppTheme.textWhite14,
          ),
          AppTheme.spacer8,
          Row(
            children: [
              Expanded(
                child: Text(
                  family.inviteCode,
                  style: const TextStyle(
                    color: AppTheme.cardColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),
              // 复制按钮
              IconButton(
                icon: const Icon(Icons.copy, color: AppTheme.cardColor),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: family.inviteCode));
                  context.showSuccessSnackBar(AppTheme.msgInviteCodeCopied);
                },
                tooltip: '复制邀请码',
              ),
              // 刷新按钮
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.cardColor),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
                      title: const Text('刷新邀请码'),
                      content: const Text('刷新后旧邀请码将失效，确定要刷新吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(AppTheme.msgCancel),
                        ),
                        PrimaryButton(
                          text: AppTheme.msgConfirm,
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final success = await ref.read(familyProvider.notifier).refreshInviteCode();
                  if (mounted) {
                    if (success) {
                      context.showSuccessSnackBar(AppTheme.msgInviteRefreshed);
                    } else {
                      context.showErrorSnackBar(AppTheme.msgOperationFailed);
                    }
                  }
                },
                tooltip: '刷新邀请码',
              ),
            ],
          ),
          AppTheme.spacer4,
          Text(
            '将邀请码分享给家人，提交后需审批通过',
            style: TextStyle(
              color: AppTheme.cardColor.withValues(alpha: 0.8),
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
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
      child: Padding(
        padding: AppTheme.paddingAll24,
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.radiusXL,
              ),
              child: const Icon(Icons.home, size: 40, color: AppTheme.primaryColor),
            ),
            AppTheme.spacer16,
            const Text('您还没有创建家庭组', style: AppTheme.textTitle),
            AppTheme.spacer8,
            const Text('创建家庭组后，可以邀请家人加入', style: AppTheme.textGrey),
            AppTheme.spacer20,
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
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
      child: Padding(
        padding: AppTheme.paddingAll24,
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.radiusXL,
              ),
              child: const Icon(Icons.group_add, size: 40, color: AppTheme.warningColor),
            ),
            AppTheme.spacer16,
            const Text('您还未加入家庭组', style: AppTheme.textTitle),
            AppTheme.spacer8,
            const Text('请让子女分享邀请码给您', style: AppTheme.textGrey),
            AppTheme.spacer20,
            PrimaryButton(
              text: '输入邀请码加入',
              onPressed: () => _showJoinFamilyDialog(),
              gradient: const LinearGradient(
                colors: [AppTheme.warningColor, AppTheme.deepOrangeColor],
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
          child: Text('暂无家庭成员', style: AppTheme.textSecondary16),
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
      elevation: AppTheme.cardElevationLow,
      margin: AppTheme.marginBottom12,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
      child: Padding(
        padding: AppTheme.paddingAll16,
        child: Row(
          children: [
            // 头像
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (member.role.isElder ? AppTheme.warningColor : AppTheme.infoBlue).withValues(alpha: 0.15),
                borderRadius: AppTheme.radiusM,
              ),
              child: ClipRRect(
                borderRadius: AppTheme.radiusM,
                child: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: member.avatarUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 256,
                        memCacheHeight: 256,
                        maxWidthDiskCache: 512,
                        maxHeightDiskCache: 512,
                        errorWidget: (_, __, ___) => Icon(
                          member.role.isElder ? Icons.elderly : Icons.person,
                          color: member.role.isElder ? AppTheme.warningColor : AppTheme.infoBlue,
                          size: 28,
                        ),
                      )
                    : Icon(
                        member.role.isElder ? Icons.elderly : Icons.person,
                        color: member.role.isElder ? AppTheme.warningColor : AppTheme.infoBlue,
                        size: 28,
                      ),
              ),
            ),
            AppTheme.hSpacer16,
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.realName.isEmpty ? '未设置姓名' : member.realName,
                    style: AppTheme.textTitle,
                  ),
                  AppTheme.spacer4,
                  Row(
                    children: [
                      Container(
                        padding: AppTheme.paddingH8V2,
                        decoration: BoxDecoration(
                          color: (member.role.isElder ? AppTheme.warningColor : AppTheme.infoBlue).withValues(alpha: 0.1),
                          borderRadius: AppTheme.radius6,
                        ),
                        child: Text(
                          member.role.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: member.role.isElder ? AppTheme.warningColor : AppTheme.infoBlue,
                          ),
                        ),
                      ),
                      AppTheme.hSpacer8,
                      Text(
                        member.relation,
                        style: AppTheme.textSubtitle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 移除按钮（子女端可操作）
            if (!isElder)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorMedium),
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
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radius10,
              ),
              child: const Icon(Icons.home, color: AppTheme.primaryColor),
            ),
            AppTheme.hSpacer12,
            const Text('创建家庭组'),
          ],
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: '家庭组名称',
            hintText: '如：张家',
            border: OutlineInputBorder(borderRadius: AppTheme.radiusS),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTheme.msgCancel),
          ),
          PrimaryButton(
            text: '创建',
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final success = await ref.read(familyProvider.notifier).createFamily(name);
              if (mounted) {
                if (success) {
                  context.showSuccessSnackBar(AppTheme.msgFamilyCreated);
                } else {
                  context.showErrorSnackBar(AppTheme.msgFamilyCreateFailed);
                }
              }
            },
          ),
        ],
      ),
    ).then((_) {
      // 延迟到下一帧释放控制器，确保对话框 Widget 树已完全卸载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
      });
    });
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
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radius10,
                    ),
                    child: const Icon(Icons.vpn_key, color: AppTheme.warningColor),
                  ),
                  AppTheme.hSpacer12,
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
                      border: OutlineInputBorder(borderRadius: AppTheme.radiusS),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  AppTheme.spacer12,
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use - StatefulBuilder 中动态更新需要 value
                    value: selectedRelation,
                    decoration: InputDecoration(
                      labelText: '您与创建者的关系',
                      prefixIcon: const Icon(Icons.people),
                      border: OutlineInputBorder(borderRadius: AppTheme.radiusS),
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
                  child: const Text(AppTheme.msgCancel),
                ),
                PrimaryButton(
                  text: '提交申请',
                  gradient: const LinearGradient(
                    colors: [AppTheme.warningColor, AppTheme.deepOrangeColor],
                  ),
                  onPressed: () async {
                    final code = codeController.text.trim();
                    if (code.length != 6 || selectedRelation == null) {
                      context.showWarningSnackBar(AppTheme.msgInviteCodeRequired);
                      return;
                    }
                    Navigator.pop(ctx);
                    final result = await ref.read(familyProvider.notifier).joinFamily(
                      inviteCode: code,
                      relation: selectedRelation!,
                    );
                    if (mounted) {
                      if (result != null) {
                        // 申请已提交
                        context.showSuccessSnackBar(result.message);
                      } else {
                        context.showErrorSnackBar(AppTheme.msgApplyFailed);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        codeController.dispose();
      });
    });
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
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radius10,
                    ),
                    child: const Icon(Icons.person_add, color: AppTheme.primaryColor),
                  ),
                  AppTheme.hSpacer12,
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
                      border: OutlineInputBorder(borderRadius: AppTheme.radiusS),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  AppTheme.spacer16,
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use - StatefulBuilder 中动态更新需要 value
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: '角色',
                      border: OutlineInputBorder(borderRadius: AppTheme.radiusS),
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
                  AppTheme.spacer16,
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use - StatefulBuilder 中动态更新需要 value
                    value: selectedRelation,
                    decoration: InputDecoration(
                      labelText: '称呼',
                      prefixIcon: const Icon(Icons.people),
                      border: OutlineInputBorder(borderRadius: AppTheme.radiusS),
                    ),
                    items: relationItems,
                    onChanged: (v) => setDialogState(() => selectedRelation = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(AppTheme.msgCancel),
                ),
                PrimaryButton(
                  text: '添加',
                  onPressed: () async {
                    final phone = phoneController.text.trim();
                    if (phone.isEmpty || selectedRelation == null) return;
                    // 前端手机号格式校验（11 位中国手机号）
                    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
                      ctx.showErrorSnackBar(AppTheme.msgInvalidPhoneFormat);
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await ref.read(familyProvider.notifier).addMember(
                      phoneNumber: phone,
                      role: selectedRole == 'elder' ? UserRole.elder : UserRole.child,
                      relation: selectedRelation!,
                    );
                    if (mounted) {
                      if (success) {
                        context.showSuccessSnackBar(AppTheme.msgMemberAdded);
                      } else {
                        context.showErrorSnackBar(AppTheme.msgMemberAddFailed);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        phoneController.dispose();
      });
    });
  }

  /// 确认移除成员
  void _confirmRemove(FamilyMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
        title: const Text('移除成员'),
        content: Text('确定要将 ${member.realName} 移出家庭组吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTheme.msgCancel),
          ),
          PrimaryButton(
            text: '移除',
            gradient: const LinearGradient(colors: [AppTheme.errorColor, AppTheme.errorAccent]),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(familyProvider.notifier).removeMember(member.userId);
              if (mounted) {
                if (success) {
                  context.showSuccessSnackBar(AppTheme.msgMemberRemoved);
                } else {
                  context.showErrorSnackBar(AppTheme.msgMemberRemoveFailed);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
