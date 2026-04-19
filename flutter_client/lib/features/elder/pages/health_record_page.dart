import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/health_record.dart';
import '../../../shared/models/health_stats.dart';
import '../providers/health_provider.dart';
import '../services/voice_input_service.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';

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
            onPressed: () => context.push('/elder/health/trend'),
            tooltip: '查看趋势',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.all(20),
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

              // 统计概览
              statsAsync.when(
                data: (stats) => _buildStatsBar(stats),
                loading: () => Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('加载统计中...', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // 记录列表标题
              const Text(
                '最近记录',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minHeight: 48, maxHeight: 64),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryLight.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final stat = stats[index];
          final avg7 = stat.average7Days?.toStringAsFixed(1) ?? '--';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stat.typeName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    avg7,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 记录列表
  Widget _buildRecordList(HealthRecordsState state) {
    if (state.isLoading && state.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(
              '加载失败: ${state.error}',
              style: const TextStyle(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: '重试',
              onPressed: () => ref.read(healthRecordsProvider.notifier).loadRecords(),
            ),
          ],
        ),
      );
    }

    if (state.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无健康记录\n点击上方卡片开始记录',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.records.length,
      itemBuilder: (context, index) {
        final record = state.records[index];
        return _buildRecordItem(record);
      },
    );
  }

  /// 单条记录项
  Widget _buildRecordItem(HealthRecord record) {
    // 格式化时间为本地时间
    final localTime = record.recordedAt.toLocal();
    final timeStr =
        '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} '
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';

    // 判断数值是否异常
    final abnormalLabel = _getAbnormalLabel(record);
    final abnormal = abnormalLabel != null;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: abnormal
            ? BorderSide(color: Colors.orange.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (abnormal ? Colors.orange : record.type.color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                abnormal ? Icons.warning_amber : record.type.icon,
                color: abnormal ? Colors.orange : record.type.color,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: abnormal ? Colors.orange.shade700 : null,
                        ),
                      ),
                      if (abnormal) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            abnormalLabel,
                            style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: type.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: type.color),
                          const SizedBox(width: 8),
                          Text(
                            _getNormalRangeHint(type),
                            style: TextStyle(fontSize: 14, color: type.color),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 语音输入区域
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isListening
                            ? LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                                  AppTheme.primaryLight.withValues(alpha: 0.05),
                                ],
                              )
                            : null,
                        color: isListening ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: isListening
                            ? Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Column(
                        children: [
                          // 语音按钮
                          GestureDetector(
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
                                if (!available) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('语音识别不可用，请检查设备设置'),
                                        backgroundColor: AppTheme.warningColor,
                                      ),
                                    );
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
                                // listen 结束后更新状态
                                if (!started) {
                                  setDialogState(() => isListening = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('语音识别启动失败，请手动输入'),
                                        backgroundColor: AppTheme.warningColor,
                                      ),
                                    );
                                  }
                                } else {
                                  setDialogState(() => isListening = voiceService.isListening);
                                }
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isListening ? 72 : 64,
                              height: isListening ? 72 : 64,
                              decoration: BoxDecoration(
                                gradient: isListening
                                    ? const LinearGradient(
                                        colors: [Colors.red, Colors.redAccent],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          AppTheme.primaryColor,
                                          AppTheme.primaryColor.withValues(alpha: 0.7),
                                        ],
                                      ),
                                shape: BoxShape.circle,
                                boxShadow: isListening
                                    ? [
                                        BoxShadow(
                                          color: Colors.red.withValues(alpha: 0.4),
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
                              child: Icon(
                                isListening ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: isListening ? 36 : 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 提示文本
                          Text(
                            isListening
                                ? (voiceText.isEmpty ? '请说出数值...' : voiceText)
                                : '点击麦克风，语音输入${type.label}数值',
                            style: TextStyle(
                              fontSize: 14,
                              color: isListening ? AppTheme.primaryColor : Colors.grey.shade600,
                              fontWeight: isListening ? FontWeight.bold : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 根据类型显示不同输入字段
                    if (type == HealthType.bloodPressure) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: '收缩压（mmHg）',
                            hintText: '60-250',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: valueController2,
                          decoration: const InputDecoration(
                            labelText: '舒张压（mmHg）',
                            hintText: '40-150',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                    if (type == HealthType.bloodSugar)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: '血糖值（mmol/L）',
                            hintText: '1.0-35.0',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    if (type == HealthType.heartRate)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: '心率（次/分）',
                            hintText: '30-200',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    if (type == HealthType.temperature)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: '体温（°C）',
                            hintText: '35.0-42.0',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: '备注（可选）',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: 2,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    voiceService.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('取消'),
                ),
                PrimaryButton(
                  text: '保存',
                  onPressed: () async {
                    await voiceService.dispose();
                    _submitRecord(
                      ctx,
                      type,
                      valueController.text,
                      valueController2.text,
                      noteController.text,
                    );
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
      // 对话框关闭时释放语音资源
      voiceService.dispose();
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
    // 解析并验证输入值
    int? systolic, diastolic, heartRate;
    double? bloodSugar, temperature;

    try {
      switch (type) {
        case HealthType.bloodPressure:
          systolic = int.parse(valueText);
          diastolic = int.parse(valueText2);
          if (systolic < 60 || systolic > 250 || diastolic < 40 || diastolic > 150) {
            throw const FormatException('血压值超出范围');
          }
        case HealthType.bloodSugar:
          bloodSugar = double.parse(valueText);
          if (bloodSugar < 1.0 || bloodSugar > 35.0) {
            throw const FormatException('血糖值超出范围');
          }
        case HealthType.heartRate:
          heartRate = int.parse(valueText);
          if (heartRate < 30 || heartRate > 200) {
            throw const FormatException('心率值超出范围');
          }
        case HealthType.temperature:
          temperature = double.parse(valueText);
          if (temperature < 35.0 || temperature > 42.0) {
            throw const FormatException('体温值超出范围');
          }
      }
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入有效的数值'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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

    if (success && mounted) {
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${type.label}记录已保存'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      // 保存成功后刷新统计
      ref.invalidate(healthStatsProvider);
    } else if (mounted) {
      // 提交失败，保持对话框打开，让用户可以重试
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(
          content: Text('保存失败，请重试'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}