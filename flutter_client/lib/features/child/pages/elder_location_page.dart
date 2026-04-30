import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/location_record.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../shared/widgets/common_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/elder_location_map.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/family_provider.dart';
import '../providers/geo_fence_provider.dart';
import '../../shared/providers/location_provider.dart';

/// 老人位置查看页面
class ElderLocationPage extends ConsumerStatefulWidget {
  final String elderId;

  const ElderLocationPage({super.key, required this.elderId});

  @override
  ConsumerState<ElderLocationPage> createState() => _ElderLocationPageState();
}

class _ElderLocationPageState extends ConsumerState<ElderLocationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 加载围栏状态
      ref.read(elderGeoFenceProvider.notifier).loadFence(widget.elderId);
    });
  }

  Future<void> _refresh() async {
    final familyId = ref.read(familyProvider).familyId;
    if (familyId == null) return;
    ref.invalidate(familyMemberLatestLocationProvider((familyId, widget.elderId)));
    ref.invalidate(familyMemberLocationHistoryProvider((familyId, widget.elderId)));
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(familyProvider.select((s) => s.familyId));
    final elderName = ref.watch(familyProvider
        .select((s) => s.members.where((m) => m.userId == widget.elderId).firstOrNull?.realName)) ?? AppTheme.labelElder;
    final geoFenceState = ref.watch(elderGeoFenceProvider);

    if (familyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppTheme.titleLocationView)),
        body: const Center(child: Text(AppTheme.msgNotInFamilyGroup)),
      );
    }

    final latestLocationAsync = ref.watch(
      familyMemberLatestLocationProvider((familyId, widget.elderId)),
    );
    final historyAsync = ref.watch(
      familyMemberLocationHistoryProvider((familyId, widget.elderId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('$elderName - 位置'),
        actions: [
          // 设置安全区域按钮
          IconButton(
            icon: Icon(
              geoFenceState.fence?.isEnabled ?? false
                  ? Icons.security
                  : Icons.security_outlined,
              color: geoFenceState.fence?.isEnabled ?? false
                  ? AppTheme.successColor
                  : AppTheme.grey500,
            ),
            onPressed: () => _showGeoFenceDialog(context, elderName, latestLocationAsync),
            tooltip: AppTheme.titleSetGeoFence,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppTheme.paddingAll20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 围栏状态提示
              if (geoFenceState.fence != null)
                _buildFenceStatusCard(geoFenceState.fence!, elderName),

              // 当前位置
              const Text(
                AppTheme.titleCurrentLocation,
                style: AppTheme.textTitle,
              ),
              AppTheme.spacer12,
              latestLocationAsync.when(
                data: (location) => _buildLatestLocationCard(location, elderName),
                loading: () => const SkeletonCard(),
                error: (_, __) => ErrorStateWidget(
                  message: AppTheme.msgLoadFailed,
                  onRetry: () => ref.invalidate(familyMemberLatestLocationProvider((familyId, widget.elderId))),
                ),
              ),
              AppTheme.spacer24,

              // 历史轨迹
              const Text(
                AppTheme.titleHistoryTrack,
                style: AppTheme.textTitle,
              ),
              AppTheme.spacer12,
              historyAsync.when(
                data: (history) => _buildHistoryList(history),
                loading: () => Column(children: List.generate(3, (_) => const SkeletonListTile())),
                error: (_, __) => ErrorStateWidget(
                  message: AppTheme.msgLoadFailed,
                  onRetry: () => ref.invalidate(familyMemberLocationHistoryProvider((familyId, widget.elderId))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 围栏状态卡片
  Widget _buildFenceStatusCard(dynamic fence, String elderName) {
    final isEnabled = fence.isEnabled as bool;
    final radius = fence.radius as int;

    return Container(
      margin: AppTheme.marginBottom16,
      padding: AppTheme.paddingAll16,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEnabled
              ? [AppTheme.successColor.withValues(alpha: 0.15), AppTheme.successColor.withValues(alpha: 0.05)]
              : [AppTheme.grey300.withValues(alpha: 0.15), AppTheme.grey300.withValues(alpha: 0.05)],
        ),
        borderRadius: AppTheme.radiusL,
        border: Border.all(
          color: isEnabled ? AppTheme.successColor.withValues(alpha: 0.3) : AppTheme.grey500.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isEnabled ? AppTheme.successColor.withValues(alpha: 0.2) : AppTheme.grey500.withValues(alpha: 0.2),
              borderRadius: AppTheme.radius10,
            ),
            child: Icon(
              isEnabled ? Icons.security : Icons.security_outlined,
              color: isEnabled ? AppTheme.successColor : AppTheme.grey500,
              size: AppTheme.iconSizeLg,
            ),
          ),
          AppTheme.hSpacer12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnabled ? AppTheme.msgFenceEnabled : AppTheme.msgFenceDisabled,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? AppTheme.successColor : AppTheme.grey500,
                  ),
                ),
                AppTheme.spacer4,
                Text(
                  '半径: ${radius >= 1000 ? '${(radius / 1000).toStringAsFixed(1)}公里' : '$radius米'}',
                  style: AppTheme.textSubtitle,
                ),
              ],
            ),
          ),
          // 快速开关
          Switch(
            value: isEnabled,
            onChanged: (value) async {
              final centerLat = fence.centerLatitude as double;
              final centerLon = fence.centerLongitude as double;
              await ref.read(elderGeoFenceProvider.notifier).toggleEnabled(
                elderId: widget.elderId,
                centerLatitude: centerLat,
                centerLongitude: centerLon,
                radius: radius,
              );
            },
            activeThumbColor: AppTheme.successColor,
          ),
        ],
      ),
    );
  }

  /// 显示围栏设置对话框
  void _showGeoFenceDialog(BuildContext context, String elderName, AsyncValue<LocationRecord?> latestLocationAsync) {
    final fenceState = ref.read(elderGeoFenceProvider);
    final existingFence = fenceState.fence;

    // 默认使用老人当前位置作为围栏中心
    double centerLat = existingFence?.centerLatitude ?? 0;
    double centerLon = existingFence?.centerLongitude ?? 0;
    int radius = existingFence?.radius ?? 500;

    // 如果有当前位置，使用当前位置
    latestLocationAsync.whenOrNull(
      data: (location) {
        if (location != null && centerLat == 0) {
          centerLat = location.latitude;
          centerLon = location.longitude;
        }
      },
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusXL,
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radius10,
                    ),
                    child: const Icon(Icons.security, color: AppTheme.successColor),
                  ),
                  AppTheme.hSpacer12,
                  const Text(AppTheme.titleSetGeoFence),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '为 $elderName 设置安全区域，当老人离开该区域时将收到通知。',
                      style: AppTheme.textSubtitle,
                    ),
                    AppTheme.spacer16,

                    // 围栏中心位置
                    Container(
                      padding: AppTheme.paddingAll12,
                      decoration: AppTheme.decorationInput,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(AppTheme.labelFenceCenter, style: AppTheme.textBold),
                          AppTheme.spacer8,
                          if (centerLat != 0)
                            Text(
                              '纬度: ${centerLat.toStringAsFixed(4)}',
                              style: AppTheme.textBody,
                            ),
                          if (centerLon != 0)
                            Text(
                              '经度: ${centerLon.toStringAsFixed(4)}',
                              style: AppTheme.textBody,
                            ),
                          if (centerLat == 0)
                            const Text(AppTheme.msgNoLocationData, style: AppTheme.textSubtitle),
                        ],
                      ),
                    ),
                    AppTheme.spacer12,

                    // 使用当前位置按钮
                    latestLocationAsync.whenOrNull(
                      data: (location) {
                        if (location != null) {
                          return TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                centerLat = location.latitude;
                                centerLon = location.longitude;
                              });
                            },
                            icon: const Icon(Icons.my_location),
                            label: const Text(AppTheme.labelUseCurrentLocation),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ) ?? const SizedBox.shrink(),

                    AppTheme.spacer12,

                    // 半径设置
                    const Text(AppTheme.labelSafeRadius, style: AppTheme.textBold),
                    AppTheme.spacer8,
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: radius.toDouble(),
                            min: 100,
                            max: 3000,
                            divisions: 29,
                            label: radius >= 1000
                                ? '${(radius / 1000).toStringAsFixed(1)}公里'
                                : '$radius米',
                            onChanged: (value) {
                              setDialogState(() => radius = value.toInt());
                            },
                          ),
                        ),
                        AppTheme.hSpacer8,
                        Text(
                          radius >= 1000
                              ? '${(radius / 1000).toStringAsFixed(1)}公里'
                              : '$radius米',
                          style: AppTheme.textBold,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                // 删除围栏按钮（如果存在）
                if (existingFence != null)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: AppTheme.titleDeleteGeoFence,
                        message: AppTheme.msgConfirmDeleteGeoFence,
                        confirmText: AppTheme.msgDelete,
                      );
                      if (!confirmed) return;
                      final success = await ref.read(elderGeoFenceProvider.notifier).deleteFence();
                      if (success && ctx.mounted) {
                        Navigator.pop(ctx);
                        context.showSuccessSnackBar(AppTheme.msgFenceDeleted);
                      }
                    },
                    child: Text(AppTheme.msgDelete, style: AppTheme.textError),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(AppTheme.msgCancel),
                ),
                PrimaryButton(
                  text: AppTheme.msgSave,
                  onPressed: centerLat == 0
                      ? null
                      : () async {
                          final success = await ref.read(elderGeoFenceProvider.notifier).saveFence(
                            elderId: widget.elderId,
                            centerLatitude: centerLat,
                            centerLongitude: centerLon,
                            radius: radius,
                            isEnabled: true,
                          );
                          if (success && ctx.mounted) {
                            Navigator.pop(ctx);
                            context.showSuccessSnackBar(AppTheme.msgFenceSaved);
                          } else if (ctx.mounted) {
                            context.showErrorSnackBar('${AppTheme.msgFenceSaveFailed}: ${fenceState.error}');
                          }
                        },
                  gradient: const LinearGradient(
                    colors: [AppTheme.successColor, AppTheme.successLight],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 当前位置卡片
  Widget _buildLatestLocationCard(LocationRecord? location, String elderName) {
    if (location == null) {
      return Container(
        padding: AppTheme.paddingAll24,
        decoration: AppTheme.decorationCardLight,
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.location_off, size: AppTheme.iconSizeXxl, color: AppTheme.grey400),
              AppTheme.spacer12,
              const Text(AppTheme.msgNoLocationRecord, style: AppTheme.textGrey),
              const Text(AppTheme.subtitleLocationNotEnabled, style: AppTheme.textCaptionDark),
            ],
          ),
        ),
      );
    }

    // 获取围栏信息
    final geoFenceState = ref.watch(elderGeoFenceProvider);
    final fence = geoFenceState.fence;

    return Column(
      children: [
        // 地图展示
        ElderLocationMap(
          latitude: location.latitude,
          longitude: location.longitude,
          elderName: elderName,
          fenceCenterLat: fence?.centerLatitude,
          fenceCenterLon: fence?.centerLongitude,
          fenceRadius: fence?.radius,
          fenceEnabled: fence?.isEnabled ?? false,
        ),
        AppTheme.spacer16,

        // 位置详情卡片
        Card(
          elevation: AppTheme.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusL,
          ),
          child: Padding(
            padding: AppTheme.paddingAll20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: AppTheme.radiusS,
                      ),
                      child: const Icon(Icons.location_on, color: AppTheme.primaryColor, size: AppTheme.iconSize2xl),
                    ),
                    AppTheme.hSpacer16,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elderName,
                          style: AppTheme.textTitle,
                        ),
                        Text(
                          '更新于 ${location.relativeTime}',
                          style: AppTheme.textSubtitle,
                        ),
                      ],
                    ),
                  ],
                ),
                AppTheme.spacer16,
                Container(
                  padding: AppTheme.paddingAll16,
                  decoration: AppTheme.decorationInput,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.explore, size: AppTheme.iconSizeMd, color: AppTheme.grey500),
                          AppTheme.hSpacer8,
                          Text(
                            '纬度: ${location.latitude.toStringAsFixed(4)}',
                            style: AppTheme.textBody16,
                          ),
                        ],
                      ),
                      AppTheme.spacer8,
                      Row(
                        children: [
                          const Icon(Icons.explore, size: AppTheme.iconSizeMd, color: AppTheme.grey500),
                          AppTheme.hSpacer8,
                          Text(
                            '经度: ${location.longitude.toStringAsFixed(4)}',
                            style: AppTheme.textBody16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppTheme.spacer12,
                Text(
                  '精确时间: ${location.formattedTime}',
                  style: AppTheme.textCaption,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 历史轨迹列表
  Widget _buildHistoryList(List<LocationRecord> history) {
    if (history.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.map_outlined,
        title: AppTheme.msgNoHistoryRecord,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      cacheExtent: 800,
      itemCount: history.length,
      itemBuilder: (context, index) => _buildHistoryItem(history[index]),
    );
  }

  /// 单条历史记录
  Widget _buildHistoryItem(LocationRecord record) {
    return Card(
      elevation: AppTheme.cardElevationLow,
      margin: AppTheme.marginBottom8,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusM,
      ),
      child: Padding(
        padding: AppTheme.paddingAll12,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.15),
                borderRadius: AppTheme.radiusXS,
              ),
              child: const Icon(Icons.location_history, color: AppTheme.infoBlue, size: AppTheme.iconSizeMd),
            ),
            AppTheme.hSpacer12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.relativeTime,
                    style: AppTheme.textBold,
                  ),
                  Text(
                    '${record.latitude.toStringAsFixed(4)}, ${record.longitude.toStringAsFixed(4)}',
                    style: AppTheme.textCaptionDark,
                  ),
                ],
              ),
            ),
            Text(
              record.formattedTime.split(' ').last,
              style: AppTheme.textCaption,
            ),
          ],
        ),
      ),
    );
  }
}