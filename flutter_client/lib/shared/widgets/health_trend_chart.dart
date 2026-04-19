import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/models/health_record.dart';

/// 健康趋势图表组件
class HealthTrendChart extends StatelessWidget {
  final HealthType type;
  final List<HealthRecord> records;
  final int daysRange; // 7 或 30

  const HealthTrendChart({
    super.key,
    required this.type,
    required this.records,
    this.daysRange = 7,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _buildEmptyChart();
    }

    // 过滤出指定天数范围内的记录
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: daysRange));
    final filteredRecords = records
        .where((r) => r.recordedAt.isAfter(startDate))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    if (filteredRecords.isEmpty) {
      return _buildEmptyChart();
    }

    return Column(
      children: [
        // 血压图例（仅血压类型显示）
        if (type == HealthType.bloodPressure)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('收缩压', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 20),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('舒张压', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        // 图表
        SizedBox(
          height: 200,
          child: _buildLineChart(filteredRecords),
        ),
        const SizedBox(height: 16),
        // 统计摘要
        _buildStatsSummary(filteredRecords),
      ],
    );
  }

  /// 空图表提示
  Widget _buildEmptyChart() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              '暂无数据',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            Text(
              '请先录入健康数据',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建折线图
  Widget _buildLineChart(List<HealthRecord> data) {
    if (type == HealthType.bloodPressure) {
      // 血压需要两条线：收缩压和舒张压
      return LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 20,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= data.length) return const Text('');
                  final record = data[value.toInt()];
                  final date = record.recordedAt;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: _getMinValue(data) - 10,
          maxY: _getMaxValue(data) + 10,
          lineBarsData: [
            // 收缩压线（红色）
            LineChartBarData(
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.red,
                  strokeWidth: 0,
                ),
              ),
              spots: data.asMap().entries.map((entry) {
                final systolic = entry.value.systolic ?? 0;
                return FlSpot(entry.key.toDouble(), systolic.toDouble());
              }).toList(),
            ),
            // 舒张压线（蓝色）
            LineChartBarData(
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.blue,
                  strokeWidth: 0,
                ),
              ),
              spots: data.asMap().entries.map((entry) {
                final diastolic = entry.value.diastolic ?? 0;
                return FlSpot(entry.key.toDouble(), diastolic.toDouble());
              }).toList(),
            ),
          ],
        ),
      );
    }

    // 其他类型：单条线
    final spots = data.asMap().entries.map((entry) {
      final value = _getValue(entry.value);
      return FlSpot(entry.key.toDouble(), value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade300,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= data.length) return const Text('');
                final record = data[value.toInt()];
                final date = record.recordedAt;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: _getMinValueSingle(data) - 2,
        maxY: _getMaxValueSingle(data) + 2,
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: type.color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: type.color,
                strokeWidth: 0,
              ),
            ),
            spots: spots,
          ),
        ],
      ),
    );
  }

  /// 统计摘要
  Widget _buildStatsSummary(List<HealthRecord> data) {
    if (type == HealthType.bloodPressure) {
      final systolics = data.map((r) => r.systolic ?? 0).toList();
      final diastolics = data.map((r) => r.diastolic ?? 0).toList();

      final maxSys = systolics.reduce((a, b) => a > b ? a : b);
      final minSys = systolics.reduce((a, b) => a < b ? a : b);
      final avgSys = systolics.reduce((a, b) => a + b) / systolics.length;

      final avgDia = diastolics.reduce((a, b) => a + b) / diastolics.length;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('收缩压', '最高', maxSys.toString(), Colors.red),
          _buildStatItem('收缩压', '最低', minSys.toString(), Colors.red),
          _buildStatItem('舒张压', '平均', avgSys.toStringAsFixed(0), Colors.blue),
          _buildStatItem('舒张压', '平均', avgDia.toStringAsFixed(0), Colors.blue),
        ],
      );
    }

    final values = data.map((r) => _getValue(r)).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(type.label, '最高', max.toStringAsFixed(1), type.color),
        _buildStatItem(type.label, '最低', min.toStringAsFixed(1), type.color),
        _buildStatItem(type.label, '平均', avg.toStringAsFixed(1), type.color),
      ],
    );
  }

  Widget _buildStatItem(String category, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          type.unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 获取单条记录的值（用于非血压类型）
  double _getValue(HealthRecord record) {
    switch (type) {
      case HealthType.bloodPressure:
        return (record.systolic ?? 0).toDouble();
      case HealthType.bloodSugar:
        return record.bloodSugar ?? 0;
      case HealthType.heartRate:
        return (record.heartRate ?? 0).toDouble();
      case HealthType.temperature:
        return record.temperature ?? 0;
    }
  }

  /// 血压最小值（取收缩压和舒张压的最小）
  double _getMinValue(List<HealthRecord> data) {
    return data.map((r) => r.diastolic ?? 0).reduce((a, b) => a < b ? a : b).toDouble();
  }

  /// 血压最大值（取收缩压最大）
  double _getMaxValue(List<HealthRecord> data) {
    return data.map((r) => r.systolic ?? 0).reduce((a, b) => a > b ? a : b).toDouble();
  }

  double _getMinValueSingle(List<HealthRecord> data) {
    return data.map((r) => _getValue(r)).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxValueSingle(List<HealthRecord> data) {
    return data.map((r) => _getValue(r)).reduce((a, b) => a > b ? a : b);
  }
}