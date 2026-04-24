import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/neighbor_help_provider.dart';

/// 邻里互助评价页面（1-5 星 + 评语）
class NeighborHelpRatingPage extends ConsumerStatefulWidget {
  final String requestId;

  const NeighborHelpRatingPage({super.key, required this.requestId});

  @override
  ConsumerState<NeighborHelpRatingPage> createState() =>
      _NeighborHelpRatingPageState();
}

class _NeighborHelpRatingPageState
    extends ConsumerState<NeighborHelpRatingPage> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('评价互助')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('为响应邻居评分', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // 星级评分
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    iconSize: 48,
                    icon: Icon(
                      star <= _rating ? Icons.star : Icons.star_border,
                      color: star <= _rating ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () => setState(() => _rating = star),
                  );
                }),
              ),
            ),
            Center(
              child: Text(
                _ratingLabel,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),

            // 评语
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: '评语（可选）',
                hintText: '分享您的互助体验...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const Spacer(),

            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rating > 0 && !_isSubmitting ? _submitRating : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交评价'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _ratingLabel {
    return switch (_rating) {
      1 => '非常不满意',
      2 => '不太满意',
      3 => '一般',
      4 => '满意',
      5 => '非常满意',
      _ => '请选择评分',
    };
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);
    final success = await ref.read(neighborHelpProvider.notifier).rateRequest(
          requestId: widget.requestId,
          rating: _rating,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评价成功，感谢您的反馈')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(neighborHelpProvider).error ?? '评价失败')),
        );
      }
    }
  }
}
