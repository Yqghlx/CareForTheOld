import 'package:flutter/material.dart';

/// 健康记录页面
class HealthRecordPage extends StatefulWidget {
  const HealthRecordPage({super.key});

  @override
  State<HealthRecordPage> createState() => _HealthRecordPageState();
}

class _HealthRecordPageState extends State<HealthRecordPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('健康记录')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请选择要记录的健康数据:', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),

            // 健康类型选择
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 1.2,
              children: [
                _buildHealthTypeCard(
                  icon: Icons.favorite,
                  title: '血压',
                  color: Colors.red,
                  onTap: () => _showRecordDialog('血压'),
                ),
                _buildHealthTypeCard(
                  icon: Icons.water_drop,
                  title: '血糖',
                  color: Colors.blue,
                  onTap: () => _showRecordDialog('血糖'),
                ),
                _buildHealthTypeCard(
                  icon: Icons.monitor_heart,
                  title: '心率',
                  color: Colors.purple,
                  onTap: () => _showRecordDialog('心率'),
                ),
                _buildHealthTypeCard(
                  icon: Icons.thermostat,
                  title: '体温',
                  color: Colors.orange,
                  onTap: () => _showRecordDialog('体温'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 最近记录
            const Text('最近记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.favorite, color: Colors.red),
                      title: const Text('血压: 120/80 mmHg'),
                      subtitle: const Text('2026-04-11 08:30'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTypeCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showRecordDialog(String type) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('记录${type}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type == '血压')
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: '收缩压'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: '舒张压'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              if (type == '血糖')
                TextField(
                  decoration: const InputDecoration(labelText: '血糖值 (mmol/L)'),
                  keyboardType: TextInputType.number,
                ),
              if (type == '心率')
                TextField(
                  decoration: const InputDecoration(labelText: '心率 (次/分)'),
                  keyboardType: TextInputType.number,
                ),
              if (type == '体温')
                TextField(
                  decoration: const InputDecoration(labelText: '体温 (°C)'),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: '备注（可选）'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${type}记录已保存')),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}