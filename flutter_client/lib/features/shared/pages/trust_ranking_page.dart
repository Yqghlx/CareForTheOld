import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/common_states.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/trust_score_provider.dart';
import '../services/trust_score_service.dart';

/// 信任排行榜页面 — 展示邻里圈内邻居的信任评分排名
class TrustRankingPage extends ConsumerStatefulWidget {
  final String circleId;

  const TrustRankingPage({super.key, required this.circleId});

  @override
  ConsumerState<TrustRankingPage> createState() => _TrustRankingPageState();
}

class _TrustRankingPageState extends ConsumerState<TrustRankingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trustScoreProvider.notifier).loadRanking(widget.circleId);
      ref.read(trustScoreProvider.notifier).loadMyScore(widget.circleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trustScoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppTheme.titleTrustRanking)),
      body: state.isLoading
          ? SingleChildScrollView(
              padding: AppTheme.paddingAll16,
              child: Column(children: List.generate(5, (_) => const SkeletonCard())),
            )
          : state.error != null
              ? ErrorStateWidget(
                  message: ErrorStateWidget.friendlyMessage(state.error),
                  onRetry: () =>
                      ref.read(trustScoreProvider.notifier).loadRanking(widget.circleId),
                )
              : state.rankings.isEmpty
                  ? const Center(child: Text(AppTheme.msgNoTrustData))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(trustScoreProvider.notifier).loadRanking(widget.circleId);
                        await ref.read(trustScoreProvider.notifier).loadMyScore(widget.circleId);
                      },
                      child: ListView.builder(
                        padding: AppTheme.paddingAll16,
                        itemCount: state.rankings.length,
                        cacheExtent: 800,
                        itemBuilder: (context, index) {
                          final item = state.rankings[index];
                          return _buildRankingCard(context, item, state.myScore);
                        },
                      ),
                    ),
    );
  }

  Widget _buildRankingCard(BuildContext context, TrustRankingItem item, double myScore) {
    // 前三名特殊样式
    final isTop3 = item.rank <= 3;
    final medalColors = [null, AppTheme.amberColor, AppTheme.grey400, AppTheme.brownColor];
    final medalIcons = [null, Icons.emoji_events, Icons.emoji_events, Icons.emoji_events];

    return Card(
      key: ValueKey(item.userId),
      margin: AppTheme.marginBottom8,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              child: isTop3
                  ? Icon(medalIcons[item.rank],
                      color: medalColors[item.rank], size: AppTheme.iconSize2xl)
                  : Text('#${item.rank}',
                      style: AppTheme.textBody18.copyWith(
                            color: AppTheme.grey600,
                          )),
            ),
            AppTheme.hSpacer8,
            CircleAvatar(child: Text(item.userName[0])),
          ],
        ),
        title: Text(item.userName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '互助 ${item.totalHelps} 次 | 评分 ${item.avgRating.toStringAsFixed(1)} | 响应率 ${item.responseRate.toStringAsFixed(0)}%',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.score.toStringAsFixed(1),
              style: AppTheme.textLargeTitle.copyWith(
                    color: AppTheme.primaryColor,
                  ),
            ),
            const Text('信任分', style: AppTheme.textCaption),
          ],
        ),
      ),
    );
  }
}
