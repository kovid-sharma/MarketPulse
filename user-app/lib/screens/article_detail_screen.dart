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

// ── Effect colour helpers ───────────────────────────────────────────────────

Color _effectColor(String effect) {
  switch (effect) {
    case 'high':
      return const Color(0xFFEF4444);
    case 'medium':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF10B981);
  }
}

Color _effectBg(String effect) {
  switch (effect) {
    case 'high':
      return const Color(0xFFEF4444).withOpacity(0.12);
    case 'medium':
      return const Color(0xFFF59E0B).withOpacity(0.12);
    default:
      return const Color(0xFF10B981).withOpacity(0.12);
  }
}

Color _effectBorder(String effect) {
  switch (effect) {
    case 'high':
      return const Color(0xFFEF4444).withOpacity(0.4);
    case 'medium':
      return const Color(0xFFF59E0B).withOpacity(0.4);
    default:
      return const Color(0xFF10B981).withOpacity(0.4);
  }
}

/// Number of filled blocks: high → 5, medium → 3, low → 1
int _effectBlocks(String effect) {
  switch (effect) {
    case 'high':
      return 5;
    case 'medium':
      return 3;
    default:
      return 1;
  }
}

// ── Main article body ───────────────────────────────────────────────────────

class _ArticleBody extends StatelessWidget {
  final Article article;
  const _ArticleBody({required this.article});

  @override
  Widget build(BuildContext context) {
    final stockImpacts = article.stockImpacts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Meta row ───────────────────────────────────────────────────
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

          // ── Headline ───────────────────────────────────────────────────
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

          // ── Summary card ───────────────────────────────────────────────
          if (article.summary != null && article.summary!.isNotEmpty)
            _InfoCard(
              icon: Icons.summarize_outlined,
              title: 'AI Summary',
              content: article.summary!,
              iconColor: const Color(0xFF6366F1),
            ),
          const SizedBox(height: 12),

          // ── Context card ───────────────────────────────────────────────
          if (article.context != null && article.context!.isNotEmpty)
            _InfoCard(
              icon: Icons.info_outline,
              title: 'Why It Matters',
              content: article.context!,
              iconColor: const Color(0xFF0EA5E9),
            ),
          const SizedBox(height: 12),

          // ── Impact explanation ─────────────────────────────────────────
          if (article.impactExplanation != null &&
              article.impactExplanation!.isNotEmpty)
            _InfoCard(
              icon: Icons.trending_up_rounded,
              title: 'Market Impact',
              content: article.impactExplanation!,
              iconColor: const Color(0xFF10B981),
            ),
          const SizedBox(height: 12),

          // ── Key takeaway ───────────────────────────────────────────────
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

          // ── Markets Affected ───────────────────────────────────────────
          if (article.marketsAffected.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader(
              icon: Icons.bar_chart_rounded,
              title: 'Markets Affected',
              iconColor: const Color(0xFFA78BFA),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: article.marketsAffected
                  .map((m) => _MarketChip(label: m))
                  .toList(),
            ),
          ],

          // ── Stocks Affected (rich tiles with block bars) ───────────────
          if (stockImpacts.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.show_chart_rounded,
              title: 'Stocks Affected',
              iconColor: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            _StocksGrid(stockImpacts: stockImpacts),
          ],

          // ── Trade Logic ────────────────────────────────────────────────
          if (article.tradeLogic != null &&
              article.tradeLogic!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _TradeLogicCard(logic: article.tradeLogic!),
          ],

          // ── Read full article button ───────────────────────────────────
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

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 17),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ── Market chip ─────────────────────────────────────────────────────────────

class _MarketChip extends StatelessWidget {
  final String label;
  const _MarketChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFA78BFA).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFA78BFA),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Stocks grid ─────────────────────────────────────────────────────────────

class _StocksGrid extends StatelessWidget {
  final List<StockImpact> stockImpacts;
  const _StocksGrid({required this.stockImpacts});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stockImpacts
          .map((s) => SizedBox(
                width: (MediaQuery.of(context).size.width - 50) / 2,
                child: _StockEffectTile(stock: s),
              ))
          .toList(),
    );
  }
}

// ── Stock effect tile ────────────────────────────────────────────────────────

class _StockEffectTile extends StatelessWidget {
  final StockImpact stock;
  const _StockEffectTile({required this.stock});

  @override
  Widget build(BuildContext context) {
    final col = _effectColor(stock.effect);
    final bg = _effectBg(stock.effect);
    final border = _effectBorder(stock.effect);
    final filled = _effectBlocks(stock.effect);

    String dirArrow = '━';
    if (stock.direction == 'positive') dirArrow = '▲';
    if (stock.direction == 'negative') dirArrow = '▼';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Symbol + direction
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stock.symbol,
                style: TextStyle(
                  color: col,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                dirArrow,
                style: TextStyle(color: col, fontSize: 12),
              ),
            ],
          ),
          if (stock.name != null &&
              stock.name!.isNotEmpty &&
              stock.name != stock.symbol) ...[
            const SizedBox(height: 3),
            Text(
              stock.name!,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          // Block bar
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i < 4 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: (i < filled) ? col : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Effect label + sector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${stock.effect.toUpperCase()} IMPACT',
                style: TextStyle(
                  color: col,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              if (stock.sector != null && stock.sector!.isNotEmpty)
                Flexible(
                  child: Text(
                    stock.sector!,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          if (stock.reason != null && stock.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              stock.reason!,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                height: 1.45,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Trade logic card ─────────────────────────────────────────────────────────

class _TradeLogicCard extends StatelessWidget {
  final String logic;
  const _TradeLogicCard({required this.logic});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x146366F1),
            Color(0x0D8B5CF6),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFF818CF8), size: 16),
              SizedBox(width: 8),
              Text(
                'Logic Behind the Trade',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            logic,
            style: const TextStyle(
              color: Color(0xFFB0B3C6),
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info card ────────────────────────────────────────────────────────────────

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

// ── Meta badge ───────────────────────────────────────────────────────────────

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
          style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }
}

// ── Sentiment badge ──────────────────────────────────────────────────────────

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
