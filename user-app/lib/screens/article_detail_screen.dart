import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../services/api_client.dart';

final articleDetailProvider =
    FutureProvider.autoDispose.family<Article, String>((ref, id) async {
  return ref.watch(apiClientProvider).getArticle(id);
});

class ArticleDetailScreen extends ConsumerWidget {
  final String articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleDetailProvider(articleId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Article',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: articleAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1))),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Color(0xFF8B8FA8))),
        ),
        data: (article) => _ArticleBody(article: article),
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  final Article article;
  const _ArticleBody({required this.article});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta row
          Row(
            children: [
              if (article.source != null)
                _MetaBadge(
                    label: article.source!, color: const Color(0xFF4B5563)),
              const SizedBox(width: 8),
              if (article.geography != null)
                _MetaBadge(
                    label: article.geography!.toUpperCase(),
                    color: const Color(0xFF1E3A5F),
                    textColor: const Color(0xFF60A5FA)),
              const Spacer(),
              _SentimentBadge(sentiment: article.sentiment),
            ],
          ),
          const SizedBox(height: 16),
          // Headline
          Text(
            article.headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (article.publishedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatDate(article.publishedAt!),
              style:
                  const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          // Summary card
          if (article.summary != null && article.summary!.isNotEmpty)
            _InfoCard(
              icon: Icons.summarize_outlined,
              title: 'Summary',
              content: article.summary!,
              iconColor: const Color(0xFF6366F1),
            ),
          const SizedBox(height: 12),
          // Context card
          if (article.context != null && article.context!.isNotEmpty)
            _InfoCard(
              icon: Icons.info_outline,
              title: 'Why It Matters',
              content: article.context!,
              iconColor: const Color(0xFF0EA5E9),
            ),
          const SizedBox(height: 12),
          // Impact explanation
          if (article.impactExplanation != null &&
              article.impactExplanation!.isNotEmpty)
            _InfoCard(
              icon: Icons.trending_up_rounded,
              title: 'Market Impact',
              content: article.impactExplanation!,
              iconColor: const Color(0xFF10B981),
            ),
          const SizedBox(height: 12),
          // Key takeaway
          if (article.keyTakeaway != null && article.keyTakeaway!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.15),
                    const Color(0xFF8B5CF6).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded,
                          color: Color(0xFFFFD700), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Key Takeaway',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.keyTakeaway!,
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          if (article.affectedStocks.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Affected Stocks',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: article.affectedStocks
                  .map((s) => _StockPill(symbol: s,
                      direction: _getDirection(article, s)))
                  .toList(),
            ),
          ],
          if (article.url != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(article.url!)),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Read Full Article'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getDirection(Article a, String stock) {
    if (a.impacts == null) return 'neutral';
    for (final impact in a.impacts!) {
      final stocks = (impact['stocks'] as List?)?.cast<String>() ?? [];
      if (stocks.contains(stock)) {
        return impact['direction'] as String? ?? 'neutral';
      }
    }
    return 'neutral';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color iconColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFFB0B3C6),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _MetaBadge({
    required this.label,
    required this.color,
    this.textColor = const Color(0xFF8B8FA8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _SentimentBadge extends StatelessWidget {
  final String? sentiment;
  const _SentimentBadge({this.sentiment});

  @override
  Widget build(BuildContext context) {
    if (sentiment == null) return const SizedBox.shrink();
    final (color, label) = switch (sentiment) {
      'bullish' => (const Color(0xFF00C851), '▲ BULLISH'),
      'bearish' => (const Color(0xFFFF4444), '▼ BEARISH'),
      _ => (const Color(0xFF8B8FA8), '━ NEUTRAL'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _StockPill extends StatelessWidget {
  final String symbol;
  final String direction;
  const _StockPill({required this.symbol, required this.direction});

  @override
  Widget build(BuildContext context) {
    final color = switch (direction) {
      'positive' => const Color(0xFF00C851),
      'negative' => const Color(0xFFFF4444),
      _ => const Color(0xFF6B7280),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            direction == 'positive'
                ? Icons.arrow_upward_rounded
                : direction == 'negative'
                    ? Icons.arrow_downward_rounded
                    : Icons.remove_rounded,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(symbol,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
