import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/article.dart';
import '../services/api_client.dart';

final reviewQueueProvider = FutureProvider.autoDispose<List<Article>>((ref) {
  return ref.watch(apiClientProvider).getReviewQueue();
});

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(reviewQueueProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        title: const Text('Review Queue',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8B8FA8)),
            onPressed: () => ref.refresh(reviewQueueProvider),
          ),
        ],
      ),
      body: queueAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (e, _) => Center(
          child:
              Text('Error: $e', style: const TextStyle(color: Color(0xFF8B8FA8))),
        ),
        data: (articles) {
          if (articles.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF00C851), size: 56),
                  SizedBox(height: 16),
                  Text('All caught up!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('No articles need review.',
                      style: TextStyle(color: Color(0xFF6B7280))),
                ],
              ),
            );
          }
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: const Color(0xFF1A1D2E),
                child: Row(
                  children: [
                    const Icon(Icons.swipe_rounded,
                        color: Color(0xFF6B7280), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${articles.length} articles need review · Swipe to act',
                      style:
                          const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: articles.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFF2A2D3E), height: 1),
                  itemBuilder: (ctx, i) =>
                      _ReviewTile(article: articles[i], ref: ref),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Article article;
  final WidgetRef ref;
  const _ReviewTile({required this.article, required this.ref});

  Future<void> _act(BuildContext context, String action) async {
    try {
      await ref.read(apiClientProvider).reviewArticle(article.id, action);
      ref.invalidate(reviewQueueProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Article ${action}d'),
          backgroundColor:
              action == 'approve' ? const Color(0xFF00C851) : const Color(0xFFFF4444),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(article.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _act(context, 'approve'),
            backgroundColor: const Color(0xFF00C851),
            foregroundColor: Colors.white,
            icon: Icons.check_rounded,
            label: 'Approve',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _act(context, 'reject'),
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.close_rounded,
            label: 'Reject',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (article.classificationConfidence != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _confidenceColor(article.classificationConfidence!)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(article.classificationConfidence! * 100).toStringAsFixed(0)}% confidence',
                      style: TextStyle(
                        color: _confidenceColor(
                            article.classificationConfidence!),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                if (article.source != null)
                  Text(article.source!,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              article.headline,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (article.summary != null && article.summary!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                article.summary!,
                style: const TextStyle(
                    color: Color(0xFF8B8FA8), fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _Badge(
                    label: article.credibility ?? 'unknown',
                    color: const Color(0xFF4B5563)),
                const SizedBox(width: 6),
                _Badge(
                    label: article.geography ?? 'unknown',
                    color: const Color(0xFF1E3A5F),
                    textColor: const Color(0xFF60A5FA)),
                const Spacer(),
                const Text('← Approve  Reject →',
                    style: TextStyle(
                        color: Color(0xFF4B5563), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _confidenceColor(double conf) {
    if (conf >= 0.7) return const Color(0xFF00C851);
    if (conf >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Badge(
      {required this.label,
      required this.color,
      this.textColor = const Color(0xFF8B8FA8)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: textColor, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
