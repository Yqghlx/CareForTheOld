import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/location_record.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/family_provider.dart';
import '../../shared/providers/location_provider.dart';

/// 老人位置查看页面
class ElderLocationPage extends ConsumerStatefulWidget {
  final String elderId;

  const ElderLocationPage({super.key, required this.elderId});

  @override
  ConsumerState<ElderLocationPage> createState() => _ElderLocationPageState();
}

class _ElderLocationPageState extends ConsumerState<ElderLocationPage> {
  Future<void> _refresh() async {
    final familyId = ref.read(familyProvider).familyId;
    if (familyId == null) return;
    ref.invalidate(familyMemberLatestLocationProvider((familyId, widget.elderId)));
    ref.invalidate(familyMemberLocationHistoryProvider((familyId, widget.elderId)));
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final familyId = familyState.familyId;
    final elder = familyState.members.where((m) => m.userId == widget.elderId).firstOrNull;
    final elderName = elder?.realName ?? '老人';

    if (familyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('位置查看')),
        body: const Center(child: Text('未加入家庭组')),
      );
    }

    final latestLocationAsync = ref.watch(
      familyMemberLatestLocationProvider((familyId, widget.elderId)),
    );
    final historyAsync = ref.watch(
      familyMemberLocationHistoryProvider((familyId, widget.elderId)),
    );

    return Scaffold(
      appBar: AppBar(title: Text('$elderName - 位置')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 当前位置
              const Text(
                '当前位置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              latestLocationAsync.when(
                data: (location) => _buildLatestLocationCard(location, elderName),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('加载失败: $e', style: const TextStyle(color: AppTheme.errorColor)),
                ),
              ),
              const SizedBox(height: 24),

              // 历史轨迹
              const Text(
                '历史轨迹',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              historyAsync.when(
                data: (history) => _buildHistoryList(history),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载失败: $e', style: const TextStyle(color: AppTheme.errorColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 当前位置卡片
  Widget _buildLatestLocationCard(LocationRecord? location, String elderName) {
    if (location == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('暂无位置记录', style: TextStyle(color: Colors.grey)),
              const Text('老人尚未开启定位上报', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elderName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '更新于 ${location.relativeTime}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.explore, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '纬度: ${location.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.explore, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '经度: ${location.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '精确时间: ${location.formattedTime}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  /// 历史轨迹列表
  Widget _buildHistoryList(List<LocationRecord> history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('暂无历史记录', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: history.map((record) => _buildHistoryItem(record)).toList(),
    );
  }

  /// 单条历史记录
  Widget _buildHistoryItem(LocationRecord record) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_history, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.relativeTime,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${record.latitude.toStringAsFixed(4)}, ${record.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Text(
              record.formattedTime.split(' ').last,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}