import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';

import '../../../shared/widgets/common_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../providers/neighbor_circle_provider.dart';


/// 邻里圈管理页面（创建/搜索/加入/退出）
class NeighborCirclePage extends ConsumerStatefulWidget {
  const NeighborCirclePage({super.key});

  @override
  ConsumerState<NeighborCirclePage> createState() => _NeighborCirclePageState();
}

class _NeighborCirclePageState extends ConsumerState<NeighborCirclePage> {
  final _inviteCodeController = TextEditingController();
  final _circleNameController = TextEditingController();
  bool _isSearching = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    // 页面加载时获取我的邻里圈
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(neighborCircleProvider.notifier).loadMyCircle());
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _circleNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(neighborCircleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppTheme.titleNeighborCircle)),
      body: state.isLoading
          ? SingleChildScrollView(
              padding: AppTheme.paddingAll16,
              child: Column(children: List.generate(3, (_) => const SkeletonCard())),
            )
          : state.error != null
              ? ErrorStateWidget(
                  message: ErrorStateWidget.friendlyMessage(state.error),
                  onRetry: () => ref.read(neighborCircleProvider.notifier).loadMyCircle(),
                )
              : state.hasCircle
                  ? _buildMyCircle(context, state)
                  : _buildNoCircle(context),
    );
  }

  /// 已加入邻里圈的展示
  Widget _buildMyCircle(BuildContext context, NeighborCircleState state) {
    final circle = state.circle!;
    return RefreshIndicator(
      onRefresh: () => ref.read(neighborCircleProvider.notifier).loadMyCircle(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppTheme.paddingAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 圈子信息卡片
          Card(
            child: Padding(
              padding: AppTheme.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(circle.circleName,
                      style: AppTheme.textLargeTitle),
                  AppTheme.spacer8,
                  Text('圈主：${circle.creatorName}'),
                  Text('成员数：${circle.memberCount} 人'),
                  Text('覆盖半径：${circle.radiusMeters.toInt()} 米'),
                  if (circle.inviteCode.isNotEmpty) ...[
                    AppTheme.spacer8,
                    Container(
                      padding: AppTheme.paddingAll8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: AppTheme.radiusXS,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('邀请码：${circle.inviteCode}',
                              style: AppTheme.textTitle),
                          AppTheme.hSpacer8,
                          IconButton(
                            icon: const Icon(Icons.refresh, size: AppTheme.iconSizeMd),
                            tooltip: AppTheme.tooltipRefreshCode,
                            onPressed: () => _refreshInviteCode(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AppTheme.spacer16,

          // 成员列表
          Text('圈内成员', style: AppTheme.textHeading),
          AppTheme.spacer8,
          ...state.members.map((m) => ListTile(
                key: ValueKey(m.userId),
                leading: CircleAvatar(
                  child: Text(m.realName[0]),
                ),
                title: Text(m.realName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(m.nickname ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: m.distanceMeters != null
                    ? Text('${m.distanceMeters!.toInt()} 米')
                    : null,
              )),

          if (state.members.isEmpty)
            const Padding(
              padding: AppTheme.paddingAll16,
              child: Text(AppTheme.msgNoMemberInfo),
            ),

          AppTheme.spacer16,

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.people),
                  label: const Text('查看成员'),
                  onPressed: () =>
                      ref.read(neighborCircleProvider.notifier).loadMembers(),
                ),
              ),
              AppTheme.hSpacer12,
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('退出圈子'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                  onPressed: () => _leaveCircle(),
                ),
              ),
            ],
          ),
          AppTheme.spacer12,

          // 信任排行榜入口
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.emoji_events),
              label: const Text('信任排行榜'),
              onPressed: () {
                context.push(RoutePaths.trustRanking(circle.id));
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 未加入任何邻里圈的展示
  Widget _buildNoCircle(BuildContext context) {
    return SingleChildScrollView(
      padding: AppTheme.paddingAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 加入邻里圈
          Card(
            child: Padding(
              padding: AppTheme.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('加入邻里圈', style: AppTheme.textHeading),
                  AppTheme.spacer8,
                  TextField(
                    controller: _inviteCodeController,
                    decoration: const InputDecoration(
                      labelText: AppTheme.labelInviteCode,
                      hintText: '输入 6 位数字邀请码',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  AppTheme.spacer8,
                  ElevatedButton(
                    onPressed: () => _joinCircle(),
                    child: const Text('加入'),
                  ),
                ],
              ),
            ),
          ),
          AppTheme.spacer16,

          // 创建邻里圈
          Card(
            child: Padding(
              padding: AppTheme.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('创建邻里圈', style: AppTheme.textHeading),
                  AppTheme.spacer8,
                  TextField(
                    controller: _circleNameController,
                    decoration: const InputDecoration(
                      labelText: '圈子名称',
                      hintText: '例如：阳光小区互助群',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  AppTheme.spacer8,
                  ElevatedButton(
                    onPressed: _isGettingLocation ? null : () => _createCircle(),
                    child: _isGettingLocation
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppTheme.labelCreate),
                  ),
                ],
              ),
            ),
          ),
          AppTheme.spacer16,

          // 搜索附近
          OutlinedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('搜索附近的邻里圈'),
            onPressed: _isGettingLocation ? null : () => _searchNearby(),
          ),
          if (_isSearching)
            const Padding(
              padding: AppTheme.paddingAll16,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _joinCircle() async {
    final code = _inviteCodeController.text.trim();
    if (code.length != 6) {
      _showSnackBar(AppTheme.msgInviteCodeHint);
      return;
    }
    final success =
        await ref.read(neighborCircleProvider.notifier).joinCircle(code);
    if (mounted) {
      _showSnackBar(success ? AppTheme.msgJoinSuccess : ref.read(neighborCircleProvider).error ?? AppTheme.msgOperationFailed);
    }
  }

  Future<void> _createCircle() async {
    final name = _circleNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar(AppTheme.msgCircleNameRequired);
      return;
    }
    final position = await _getCurrentPosition();
    final success =
        await ref.read(neighborCircleProvider.notifier).createCircle(
              circleName: name,
              latitude: position?.latitude ?? 39.9042,
              longitude: position?.longitude ?? 116.4074,
            );
    if (mounted) {
      _showSnackBar(success ? AppTheme.msgCreateSuccess : ref.read(neighborCircleProvider).error ?? AppTheme.msgOperationFailed);
    }
  }

  Future<void> _leaveCircle() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '确认退出',
      message: '确定要退出邻里圈吗？如果您是圈主，退出后圈子将解散。',
      confirmText: '退出',
    );
    if (!confirmed) return;
    final success =
        await ref.read(neighborCircleProvider.notifier).leaveCircle();
    if (mounted) {
      _showSnackBar(success ? AppTheme.msgLeftCircle : ref.read(neighborCircleProvider).error ?? AppTheme.msgOperationFailed);
    }
  }

  Future<void> _refreshInviteCode() async {
    final success =
        await ref.read(neighborCircleProvider.notifier).refreshInviteCode();
    if (mounted) {
      _showSnackBar(success ? AppTheme.msgInviteRefreshed : ref.read(neighborCircleProvider).error ?? AppTheme.msgOperationFailed);
    }
  }

  Future<void> _searchNearby() async {
    setState(() => _isSearching = true);
    final position = await _getCurrentPosition();
    await ref.read(neighborCircleProvider.notifier).searchNearby(
          latitude: position?.latitude ?? 39.9042,
          longitude: position?.longitude ?? 116.4074,
        );
    if (mounted) setState(() => _isSearching = false);
    final nearby = ref.read(neighborCircleProvider).nearbyCircles;
    if (nearby.isEmpty && mounted) {
      _showSnackBar(AppTheme.msgNoCircleNearby);
    }
  }

  /// 获取当前位置（权限拒绝或获取失败返回 null，不阻塞主流程）
  Future<Position?> _getCurrentPosition() async {
    setState(() => _isGettingLocation = true);
    try {
      // 检查定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showSnackBar(AppTheme.msgLocationServiceDisabled);
        return null;
      }

      // 检查权限
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _showSnackBar(AppTheme.msgLocationPermissionDenied);
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showSnackBar(AppTheme.msgLocationPermissionPermanentlyDenied);
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: AppTheme.duration5s,
      );
    } catch (_) {
      if (mounted) _showSnackBar(AppTheme.msgLocationFailed);
      return null;
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _showSnackBar(String message) {
    context.showSnackBar(message);
  }
}
