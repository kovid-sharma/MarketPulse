import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';

class ArticleCard extends ConsumerWidget {
  final Article article;
  final VoidCallback? onTap;

  const ArticleCard({super.key, required this.article, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2D3E), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: source + time + sentiment
              Row(
                children: [
                  if (article.source != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2D3E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.source!,
                        style: const TextStyle(
                          color: Color(0xFF8B8FA8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const Spacer(),
                  _SentimentChip(sentiment: article.sentiment),
                ],
              ),
              const SizedBox(height: 12),
              // Headline
              Text(
                article.headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (article.keyTakeaway != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          article.keyTakeaway!,
                          style: const TextStyle(
                            color: Color(0xFFB0B3C6),
                            fontSize: 12,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Stocks affected — show with effect colours
              if (article.stockImpacts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: article.stockImpacts
                      .take(4)
                      .map((s) => _StockEffectChip(stock: s))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              // Bottom row: geography + time
              Row(
                children: [
                  if (article.geography != null)
                    Row(
                      children: [
                        Icon(
                          article.geography == 'india'
                              ? Icons.flag
                              : Icons.public,
                          color: const Color(0xFF6B7280),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          article.geography!.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  const Spacer(),
                  if (article.publishedAt != null)
                    Text(
                      _formatTime(article.publishedAt!),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SentimentChip extends StatelessWidget {
  final String? sentiment;
  const _SentimentChip({this.sentiment});

  @override
  Widget build(BuildContext context) {
    if (sentiment == null) return const SizedBox.shrink();
    final (color, icon, label) = switch (sentiment) {
      'bullish' => (const Color(0xFF00C851), Icons.trending_up, 'BULLISH'),
      'bearish' => (const Color(0xFFFF4444), Icons.trending_down, 'BEARISH'),
      _ => (const Color(0xFF8B8FA8), Icons.trending_flat, 'NEUTRAL'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockEffectChip extends StatelessWidget {
  final StockImpact stock;
  const _StockEffectChip({required this.stock});

  static Color _col(String effect) {
    switch (effect) {
      case 'high': return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _col(stock.effect);
    final dirArrow = stock.direction == 'positive'
        ? '▲'
        : stock.direction == 'negative'
            ? '▼'
            : '■';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$dirArrow ${stock.symbol}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
