import 'package:flutter/material.dart';

/// 家庭成员管理页面
class FamilyMemberPage extends StatefulWidget {
  const FamilyMemberPage({super.key});

  @override
  State<FamilyMemberPage> createState() => _FamilyMemberPageState();
}

class _FamilyMemberPageState extends State<FamilyMemberPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('家庭成员')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.home, size: 32, color: Color(0xFFE86B4A)),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('张家', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('创建于 2026-01-01', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('家庭成员', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: 4,
                itemBuilder: (context, index) {
                  final roles = ['老人', '子女', '子女', '子女'];
                  final names = ['张奶奶', '小张', '小张妹妹', '小张弟弟'];

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index == 0 ? Colors.orange : Colors.blue,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(names[index]),
                      subtitle: Text(roles[index]),
                      trailing: index > 0
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                _showRemoveDialog(names[index]);
                              },
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // 添加成员按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddMemberDialog(),
                icon: const Icon(Icons.add),
                label: const Text('添加家庭成员'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加家庭成员'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: '手机号',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: '子女',
                decoration: const InputDecoration(labelText: '角色'),
                items: const [
                  DropdownMenuItem(value: 'elder', child: Text('老人')),
                  DropdownMenuItem(value: 'child', child: Text('子女')),
                ],
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: '称呼（如：妈妈、爸爸）'),
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
                  const SnackBar(content: Text('邀请已发送')),
                );
              },
              child: const Text('发送邀请'),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveDialog(String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('移除成员'),
          content: Text('确定要移除 $name 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('成员已移除')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );
  }
}