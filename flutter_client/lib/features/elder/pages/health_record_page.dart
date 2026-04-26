import '../../../core/router/route_paths.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/models/health_record.dart';
import '../../../shared/models/health_stats.dart';
import '../providers/health_provider.dart';
import '../services/health_service.dart';
import '../services/voice_input_service.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../shared/widgets/common_states.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/ocr_parser_service.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/extensions/date_format_extension.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// 健康记录页面
class HealthRecordPage extends ConsumerStatefulWidget {
  const HealthRecordPage({super.key});

  @override
  ConsumerState<HealthRecordPage> createState() => _HealthRecordPageState();
}

class _HealthRecordPageState extends ConsumerState<HealthRecordPage> {
  @override
  void initState() {
    super.initState();
    // 首次进入自动加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(healthRecordsProvider.notifier).loadRecords();
    });
  }

  /// 下拉刷新
  Future<void> _refresh() async {
    final filter = ref.read(healthRecordsProvider).selectedFilter;
    await ref.read(healthRecordsProvider.notifier).loadRecords(type: filter);
    // 同时刷新统计
    ref.invalidate(healthStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthRecordsProvider);
    final statsAsync = ref.watch(healthStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('健康记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () => context.push(RoutePaths.elderHealthTrend),
            tooltip: '查看趋势',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: AppTheme.paddingAll20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 健康类型选择 - 使用带动画的卡片
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: HealthType.values
                    .map((type) => _buildHealthTypeCard(type))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // 离线缓存提示
              if (healthState.isFromCache)
                Container(
                  margin: AppTheme.marginBottom12,
                  padding: AppTheme.paddingH16V8,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.radius10,
                    border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, size: 18, color: AppTheme.warningDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '网络未连接，当前显示缓存数据',
                          style: TextStyle(fontSize: 16, color: AppTheme.warningDark),
                        ),
                      ),
                    ],
                  ),
                ),

              // 统计概览
              statsAsync.when(
                data: (stats) => _buildStatsBar(stats),
                loading: () => Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: AppTheme.radiusS,
                  ),
                  child: const Center(
                    child: Text('加载统计中...', style: AppTheme.textGrey),
                  ),
                ),
                error: (_, __) => const Center(
                    child: Text('统计加载失败', style: AppTheme.textGrey),
                  ),
              ),
              const SizedBox(height: 16),

              // 记录列表标题
              const Text(
                '最近记录',
                style: AppTheme.textLargeTitle,
              ),
              const SizedBox(height: 12),

              // 记录列表
              Expanded(
                child: _buildRecordList(healthState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 健康类型选择卡片 - 使用动画卡片
  Widget _buildHealthTypeCard(HealthType type) {
    return AnimatedQuickCard(
      icon: type.icon,
      title: '记录${type.label}',
      subtitle: type.unit,
      color: type.color,
      onTap: () => _showRecordDialog(type),
    );
  }

  /// 统计概览条
  Widget _buildStatsBar(List<HealthStats> stats) {
    if (stats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: EmptyStateWidget(
          icon: Icons.analytics_outlined,
          title: '暂无统计数据',
          subtitle: '记录健康数据后，这里会显示趋势概览',
        ),
      );
    }

    // 检查是否有趋势预警
    final warnings = stats.where((s) => s.hasWarning).toList();

    return Column(
      children: [
        // 趋势预警横幅（有预警时显示）
        if (warnings.isNotEmpty)
          Container(
            margin: AppTheme.marginBottom8,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.radiusS,
              border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: warnings.map((w) => Row(
                children: [
                  Icon(w.trendIcon, size: 18, color: w.trendColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w.trendWarning ?? '',
                      style: TextStyle(fontSize: 16, color: AppTheme.grey800),
                    ),
                  ),
                ],
              )).toList(),
            ),
          ),
        // 统计概览卡片
        Container(
          constraints: const BoxConstraints(minHeight: 48, maxHeight: 80),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.08),
                AppTheme.primaryLight.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: AppTheme.radiusM,
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: AppTheme.paddingH16V8,
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final stat = stats[index];
              final avg7 = stat.average7Days?.toStringAsFixed(1) ?? '--';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: AppTheme.radius10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stat.typeName,
                            style: AppTheme.textSecondary16,
                          ),
                          // 趋势指示小图标
                          if (stat.trend != null && stat.trend != 'stable') ...[
                            const SizedBox(width: 4),
                            Icon(
                              stat.trendIcon,
                              size: 14,
                              color: stat.trendColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        avg7,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: stat.hasWarning ? stat.trendColor : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    // 30天均值和记录总数
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '30天: ${stat.average30Days?.toStringAsFixed(1) ?? '--'} | 共${stat.totalCount}条',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.grey500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 记录列表
  Widget _buildRecordList(HealthRecordsState state) {
    if (state.isLoading && state.records.isEmpty) {
      return Column(children: List.generate(3, (_) => const SkeletonCard()));
    }

    if (state.error != null && state.records.isEmpty) {
      return ErrorStateWidget(
        message: ErrorStateWidget.friendlyMessage(state.error),
        onRetry: () => ref.read(healthRecordsProvider.notifier).loadRecords(),
      );
    }

    if (state.records.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.note_add_outlined,
        title: '暂无健康记录',
        subtitle: '点击上方卡片开始记录',
      );
    }

    return ListView.builder(
      cacheExtent: 800,
      itemCount: state.records.length,
      itemBuilder: (context, index) {
        final record = state.records[index];
        return _buildRecordItem(record);
      },
    );
  }

  /// 单条记录项（支持滑动删除）
  Widget _buildRecordItem(HealthRecord record) {
    // 格式化时间为本地时间
    final localTime = record.recordedAt.toLocal();
    final timeStr = localTime.toDateTimeString();

    // 判断数值是否异常
    final abnormalLabel = _getAbnormalLabel(record);
    final abnormal = abnormalLabel != null;

    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showConfirmDialog(
        context,
        title: '确认删除',
        message: '确定删除 ${record.type.label} 记录（${record.displayValue}）吗？',
        confirmText: '删除',
      ),
      onDismissed: (_) => _deleteRecord(record.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          borderRadius: AppTheme.radiusL,
        ),
        child: const Icon(Icons.delete, color: AppTheme.errorColor, size: 28),
      ),
      child: Card(
      elevation: 4,
      margin: AppTheme.marginBottom12,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusL,
        side: abnormal
            ? BorderSide(color: AppTheme.warningColor.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: AppTheme.paddingAll16,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (abnormal ? AppTheme.warningColor : record.type.color).withValues(alpha: 0.15),
                borderRadius: AppTheme.radiusS,
              ),
              child: Icon(
                abnormal ? Icons.warning_amber : record.type.icon,
                color: abnormal ? AppTheme.warningColor : record.type.color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${record.type.label}: ${record.displayValue} ${record.type.unit}',
                        style: AppTheme.textTitle.copyWith(
                          color: abnormal ? AppTheme.warningDark : null,
                        ),
                      ),
                      if (abnormal) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: AppTheme.paddingH8V2,
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.15),
                            borderRadius: AppTheme.radius6,
                          ),
                          child: Text(
                            abnormalLabel,
                            style: const TextStyle(fontSize: 16, color: AppTheme.warningColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: AppTheme.textSecondary16,
                  ),
                  // 显示备注信息
                  if (record.note != null && record.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '备注: ${record.note}',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.grey500,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  /// 删除健康记录
  Future<void> _deleteRecord(String recordId) async {
    try {
      final service = HealthService(ref.read(apiClientProvider).dio);
      await service.deleteRecord(recordId);
      ref.read(healthRecordsProvider.notifier).loadRecords();
      if (mounted) {
        context.showSnackBar(AppTheme.msgRecordDeleted);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    }
  }

  /// 判断健康数据是否超出正常范围，返回异常标签或 null
  String? _getAbnormalLabel(HealthRecord record) {
    switch (record.type) {
      case HealthType.bloodPressure:
        if (record.systolic != null && record.systolic! > 140) return '偏高';
        if (record.systolic != null && record.systolic! < 90) return '偏低';
        if (record.diastolic != null && record.diastolic! > 90) return '偏高';
        if (record.diastolic != null && record.diastolic! < 60) return '偏低';
        return null;
      case HealthType.bloodSugar:
        if (record.bloodSugar == null) return null;
        if (record.bloodSugar! > 6.1) return '偏高';
        if (record.bloodSugar! < 3.9) return '偏低';
        return null;
      case HealthType.heartRate:
        if (record.heartRate == null) return null;
        if (record.heartRate! > 100) return '偏高';
        if (record.heartRate! < 60) return '偏低';
        return null;
      case HealthType.temperature:
        if (record.temperature == null) return null;
        if (record.temperature! > 37.3) return '偏高';
        if (record.temperature! < 36.0) return '偏低';
        return null;
    }
  }

  /// 显示录入对话框
  void _showRecordDialog(HealthType type) {
    final valueController = TextEditingController();
    final valueController2 = TextEditingController(); // 血压舒张压
    final noteController = TextEditingController();

    // 语音输入相关状态
    final voiceService = VoiceInputService();
    bool isListening = false;
    String voiceText = '';
    double soundLevel = 0;
    bool isSubmitting = false;

    // OCR 相关状态
    final ocrService = OcrParserService();
    final imagePicker = ImagePicker();

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
                      color: type.color.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radius10,
                    ),
                    child: Icon(type.icon, color: type.color),
                  ),
                  const SizedBox(width: 12),
                  Text('记录${type.label}'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 正常范围提示
                    Container(
                      padding: AppTheme.paddingH12V8,
                      decoration: BoxDecoration(
                        color: type.color.withValues(alpha: 0.08),
                        borderRadius: AppTheme.radiusXS,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: type.color),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _getNormalRangeHint(type),
                              style: TextStyle(fontSize: 16, color: type.color),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 快捷输入区域：语音 + 拍照并列
                    Container(
                      padding: AppTheme.paddingAll16,
                      decoration: BoxDecoration(
                        gradient: isListening
                            ? LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                                  AppTheme.primaryLight.withValues(alpha: 0.05),
                                ],
                              )
                            : null,
                        color: isListening ? null : AppTheme.grey50,
                        borderRadius: AppTheme.radiusL,
                        border: isListening
                            ? Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // 语音输入卡片
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    if (isListening) {
                                      // 停止录音
                                      await voiceService.stopListening();
                                      setDialogState(() => isListening = false);
                                      // 解析已识别的文本并填入
                                      if (voiceText.isNotEmpty) {
                                        _fillFromVoice(
                                          type,
                                          voiceText,
                                          valueController,
                                          valueController2,
                                        );
                                        setDialogState(() {});
                                      }
                                    } else {
                                      // 初始化并开始录音
                                      final available = await voiceService.initialize();
                                      if (!mounted || !context.mounted) return;
                                      if (!available) {
                                        if (mounted) {
                                          context.showWarningSnackBar(AppTheme.msgVoiceNotAvailable);
                                        }
                                        return;
                                      }
                                      setDialogState(() {
                                        isListening = true;
                                        voiceText = '';
                                      });
                                      final started = await voiceService.startListening(
                                        onResult: (text, isFinal) {
                                          setDialogState(() => voiceText = text);
                                          if (isFinal && text.isNotEmpty) {
                                            // 最终结果自动停止并填入
                                            voiceService.stopListening();
                                            _fillFromVoice(
                                              type,
                                              text,
                                              valueController,
                                              valueController2,
                                            );
                                            setDialogState(() => isListening = false);
                                          }
                                        },
                                        onSoundLevelChange: (level) {
                                          setDialogState(() => soundLevel = level);
                                        },
                                      );
                                      if (!started) {
                                        setDialogState(() => isListening = false);
                                        if (mounted) {
                                          context.showWarningSnackBar(AppTheme.msgVoiceInputFailed);
                                        }
                                      } else {
                                        setDialogState(() => isListening = voiceService.isListening);
                                      }
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: AppTheme.duration200ms,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      gradient: isListening
                                          ? const LinearGradient(
                                              colors: [AppTheme.errorColor, AppTheme.errorAccent],
                                            )
                                          : LinearGradient(
                                              colors: [
                                                AppTheme.primaryColor,
                                                AppTheme.primaryColor.withValues(alpha: 0.7),
                                              ],
                                            ),
                                      borderRadius: AppTheme.radiusS,
                                      boxShadow: isListening
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.errorColor.withValues(alpha: 0.4),
                                                blurRadius: 16 + soundLevel.abs(),
                                                spreadRadius: 4,
                                              ),
                                            ]
                                          : [
                                              BoxShadow(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isListening ? Icons.stop : Icons.mic,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          isListening ? '停止' : '语音输入',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 拍照识别卡片
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final image = await imagePicker.pickImage(
                                      source: ImageSource.camera,
                                      maxWidth: 1024,
                                      maxHeight: 1024,
                                      imageQuality: 85,
                                    );
                                    if (image == null) return;

                                    try {
                                      final result = await ocrService.parseHealthData(File(image.path));

                                      if (result.hasAnyData()) {
                                        // 根据健康类型填充对应的识别结果
                                        if (type == HealthType.bloodPressure) {
                                          if (result.systolic != null) {
                                            valueController.text = result.systolic.toString();
                                          }
                                          if (result.diastolic != null) {
                                            valueController2.text = result.diastolic.toString();
                                          }
                                        } else if (type == HealthType.bloodSugar) {
                                          if (result.bloodSugar != null) {
                                            valueController.text = result.bloodSugar!.toStringAsFixed(1);
                                          }
                                        } else if (type == HealthType.heartRate) {
                                          if (result.heartRate != null) {
                                            valueController.text = result.heartRate.toString();
                                          }
                                        } else if (type == HealthType.temperature) {
                                          if (result.temperature != null) {
                                            valueController.text = result.temperature!.toStringAsFixed(1);
                                          }
                                        }

                                        if (mounted) {
                                          context.showSuccessSnackBar(AppTheme.msgOcrSuccess);
                                        }
                                      } else {
                                        if (mounted) {
                                          context.showWarningSnackBar(AppTheme.msgOcrNoValue);
                                        }
                                      }
                                    } on OcrException catch (e) {
                                      if (mounted) {
                                        context.showErrorSnackBar(e.message);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        context.showErrorSnackBar(AppTheme.msgOcrFailed);
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          type.color,
                                          type.color.withValues(alpha: 0.7),
                                        ],
                                      ),
                                      borderRadius: AppTheme.radiusS,
                                      boxShadow: [
                                        BoxShadow(
                                          color: type.color.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          '拍照识别',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // 语音识别中的状态反馈
                          if (isListening) ...[
                            const SizedBox(height: 12),
                            Text(
                              voiceText.isEmpty ? '请说出数值...' : voiceText,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 根据类型显示不同输入字段
                    if (type == HealthType.bloodPressure) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.grey50,
                          borderRadius: AppTheme.radiusS,
                        ),
                        child: TextField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: '收缩压（mmHg）',
                            hintText: '60-250',
                            border: InputBorder.none,
                            contentPadding: AppTheme.paddingH16V12,
                          ),
                          keyboardType: TextInputType.number,
                          style: AppTheme.textBody18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.grey50,
                          borderRadius: AppTheme.radiusS,
                        ),
                        child: TextField(
                          controller: valueController2,
                          decoration: const InputDecoration(
                            labelText: '舒张压（mmHg）',
                            hintText: '40-150',
                            border: InputBorder.none,
                            contentPadding: AppTheme.paddingH16V12,
                          ),
                          keyboardType: TextInputType.number,
                          style: AppTheme.textBody18,
                        ),
                      ),
                    ],
                    if (type == HealthType.bloodSugar)
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.grey50,
                          borderRadius: AppTheme.radiusS,
                        ),
                        child: TextField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: '血糖值（mmol/L）',
                            hintText: '1.0-35.0',
                            border: InputBorder.none,
                            contentPadding: AppTheme.paddingH16V12,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: AppTheme.textBody18,
                        ),
                      ),
                    if (type == HealthType.heartRate)
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.grey50,
                          borderRadius: AppTheme.radiusS,
                        ),
                        child: TextField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: '心率（次/分）',
                            hintText: '30-200',
                            border: InputBorder.none,
                            contentPadding: AppTheme.paddingH16V12,
                          ),
                          keyboardType: TextInputType.number,
                          style: AppTheme.textBody18,
                        ),
                      ),
                    if (type == HealthType.temperature)
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.grey50,
                          borderRadius: AppTheme.radiusS,
                        ),
                        child: TextField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: '体温（°C）',
                            hintText: '35.0-42.0',
                            border: InputBorder.none,
                            contentPadding: AppTheme.paddingH16V12,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: AppTheme.textBody18,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.grey50,
                        borderRadius: AppTheme.radiusS,
                      ),
                      child: TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: '备注（可选）',
                          border: InputBorder.none,
                          contentPadding: AppTheme.paddingH16V12,
                        ),
                        maxLines: 2,
                        style: AppTheme.textBody16,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                PrimaryButton(
                  text: '保存',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : () async {
                    setDialogState(() => isSubmitting = true);
                    await voiceService.dispose();
                    if (!mounted || !ctx.mounted) return;
                    await _submitRecord(
                      ctx,
                      type,
                      valueController.text,
                      valueController2.text,
                      noteController.text,
                    );
                    if (ctx.mounted) {
                      setDialogState(() => isSubmitting = false);
                    }
                  },
                  gradient: LinearGradient(
                    colors: [type.color, type.color.withValues(alpha: 0.7)],
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // 延迟到下一帧释放资源，确保对话框 Widget 树已完全卸载
      // 避免在 TextField 仍依附于 TextEditingController 时调用 dispose 导致断言失败
      WidgetsBinding.instance.addPostFrameCallback((_) {
        voiceService.dispose();
        ocrService.dispose();
        valueController.dispose();
        valueController2.dispose();
        noteController.dispose();
      });
    });
  }

  /// 获取健康类型正常范围提示文字
  String _getNormalRangeHint(HealthType type) {
    switch (type) {
      case HealthType.bloodPressure:
        return '正常范围: 收缩压 90-140 / 舒张压 60-90 mmHg';
      case HealthType.bloodSugar:
        return '正常范围: 空腹 3.9-6.1 mmol/L';
      case HealthType.heartRate:
        return '正常范围: 60-100 次/分';
      case HealthType.temperature:
        return '正常范围: 36.1-37.2 °C';
    }
  }

  /// 将语音识别文本解析后填入对应的输入框
  void _fillFromVoice(
    HealthType type,
    String text,
    TextEditingController valueController,
    TextEditingController valueController2,
  ) {
    VoiceParser.parseAndFill(
      type,
      text,
      onBloodPressure: (systolic, diastolic) {
        valueController.text = systolic.toString();
        valueController2.text = diastolic.toString();
      },
      onBloodSugar: (value) {
        valueController.text = value.toStringAsFixed(1);
      },
      onHeartRate: (value) {
        valueController.text = value.toString();
      },
      onTemperature: (value) {
        valueController.text = value.toStringAsFixed(1);
      },
    );
  }

  /// 提交记录
  Future<void> _submitRecord(
    BuildContext dialogContext,
    HealthType type,
    String valueText,
    String valueText2,
    String note,
  ) async {
    // 方法入口检查：确保 widget 仍然存在
    if (!mounted) return;

    // 解析并验证输入值
    int? systolic, diastolic, heartRate;
    double? bloodSugar, temperature;
    String? abnormalHint;

    try {
      switch (type) {
        case HealthType.bloodPressure:
          systolic = int.parse(valueText);
          diastolic = int.parse(valueText2);
          if (systolic < 60 || systolic > 250 || diastolic < 40 || diastolic > 150) {
            throw const FormatException('血压值超出可记录范围（收缩压60-250，舒张压40-150）');
          }
          // 温和提示：超出正常范围但仍在可记录范围
          if (systolic > 140 || diastolic > 90) {
            abnormalHint = '血压偏高，已记录。建议关注并咨询医生。';
          } else if (systolic < 90 || diastolic < 60) {
            abnormalHint = '血压偏低，已记录。建议关注并咨询医生。';
          }
        case HealthType.bloodSugar:
          bloodSugar = double.parse(valueText);
          if (bloodSugar < 1.0 || bloodSugar > 35.0) {
            throw const FormatException('血糖值超出可记录范围（1.0-35.0 mmol/L）');
          }
          if (bloodSugar > 6.1) {
            abnormalHint = '血糖偏高，已记录。建议关注饮食并咨询医生。';
          } else if (bloodSugar < 3.9) {
            abnormalHint = '血糖偏低，已记录。请注意及时补充糖分。';
          }
        case HealthType.heartRate:
          heartRate = int.parse(valueText);
          if (heartRate < 30 || heartRate > 200) {
            throw const FormatException('心率值超出可记录范围（30-200 次/分）');
          }
          if (heartRate > 100) {
            abnormalHint = '心率偏快，已记录。建议适当休息。';
          } else if (heartRate < 60) {
            abnormalHint = '心率偏慢，已记录。如感不适请咨询医生。';
          }
        case HealthType.temperature:
          temperature = double.parse(valueText);
          if (temperature < 35.0 || temperature > 42.0) {
            throw const FormatException('体温值超出可记录范围（35.0-42.0 °C）');
          }
          if (temperature > 37.3) {
            abnormalHint = '体温偏高，已记录。建议多喝水并观察。';
          } else if (temperature < 36.0) {
            abnormalHint = '体温偏低，已记录。请注意保暖。';
          }
      }
    } on FormatException catch (e) {
      context.showErrorSnackBar(e.message);
      return;
    } catch (_) {
      context.showErrorSnackBar(AppTheme.msgInvalidValue);
      return;
    }

    // 先异步提交，成功后再关闭对话框；失败时保留对话框让用户可重试
    final success = await ref.read(healthRecordsProvider.notifier).createRecord(
          type: type,
          systolic: systolic,
          diastolic: diastolic,
          bloodSugar: bloodSugar,
          heartRate: heartRate,
          temperature: temperature,
          note: note,
        );

    if (success && mounted && context.mounted) {
      Navigator.pop(dialogContext);
      // 带动画的成功提示
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppTheme.duration500ms,
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  abnormalHint ?? '${type.label}记录已保存',
                  style: AppTheme.textBody16,
                ),
              ),
            ],
          ),
          backgroundColor: abnormalHint != null
              ? AppTheme.warningColor  // 温和提示用橙色而非红色
              : AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusS,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: AppTheme.duration2s,
        ),
      );
      // 保存成功后刷新统计
      ref.invalidate(healthStatsProvider);
    } else if (mounted && dialogContext.mounted) {
      // 提交失败，保持对话框打开，让用户可以重试
      dialogContext.showErrorSnackBar(AppTheme.msgOperationFailed);
    }
  }
}