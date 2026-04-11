import 'package:flutter/material.dart';

/// 子女查看老人健康数据页面
class ElderHealthPage extends StatefulWidget {
  final String elderId;

  const ElderHealthPage({super.key, required this.elderId});

  @override
  State<ElderHealthPage> createState() => _ElderHealthPageState();
}

class _ElderHealthPageState extends State<ElderHealthPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('张奶奶 - 健康数据')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 健康概览卡片
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 1.3,
              children: [
                _buildHealthCard(
                  icon: Icons.favorite,
                  title: '血压',
                  value: '120/80',
                  unit: 'mmHg',
                  color: Colors.red,
                  trend: '正常',
                ),
                _buildHealthCard(
                  icon: Icons.water_drop,
                  title: '血糖',
                  value: '5.6',
                  unit: 'mmol/L',
                  color: Colors.blue,
                  trend: '正常',
                ),
                _buildHealthCard(
                  icon: Icons.monitor_heart,
                  title: '心率',
                  value: '72',
                  unit: '次/分',
                  color: Colors.purple,
                  trend: '正常',
                ),
                _buildHealthCard(
                  icon: Icons.thermostat,
                  title: '体温',
                  value: '36.5',
                  unit: '°C',
                  color: Colors.orange,
                  trend: '正常',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 趋势图表占位
            const Text('健康趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.show_chart, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('近7天血压趋势', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTrendItem('周一', '118/78'),
                        _buildTrendItem('周二', '120/80'),
                        _buildTrendItem('周三', '122/82'),
                        _buildTrendItem('周四', '120/80'),
                        _buildTrendItem('周五', '119/79'),
                        _buildTrendItem('周六', '121/81'),
                        _buildTrendItem('今日', '120/80'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 用药情况
            const Text('今日用药情况', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('阿司匹林 100mg'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('已服用', style: TextStyle(color: Colors.green)),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('降压药 50mg'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('待服用', style: TextStyle(color: Colors.orange)),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('维生素 C'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('已服用', style: TextStyle(color: Colors.green)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    required String trend,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('$value $unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(trend, style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendItem(String day, String value) {
    return Column(
      children: [
        Text(day, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}