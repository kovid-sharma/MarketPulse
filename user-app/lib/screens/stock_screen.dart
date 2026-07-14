import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/stock_profile.dart';
import '../services/api_client.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final trendingStocksProvider =
    FutureProvider.autoDispose<List<TrendingStock>>((ref) async {
  return ref.watch(apiClientProvider).getTrendingStocks(limit: 30);
});

final stockProfileProvider =
    FutureProvider.autoDispose.family<StockProfile, String>((ref, symbol) async {
  return ref.watch(apiClientProvider).getStockProfile(symbol);
});

final stockNewsProvider =
    FutureProvider.autoDispose.family<List<StockNewsItem>, String>((ref, symbol) async {
  return ref.watch(apiClientProvider).getNewsForStock(symbol, limit: 30);
});

// ── Stock Screen ──────────────────────────────────────────────────────────────

class StockScreen extends ConsumerStatefulWidget {
  final String? initialSymbol;
  const StockScreen({super.key, this.initialSymbol});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedSymbol;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedSymbol = widget.initialSymbol;
    if (_selectedSymbol != null) {
      _searchController.text = _selectedSymbol!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSymbolSelected(String symbol) {
    setState(() {
      _selectedSymbol = symbol.toUpperCase().trim();
      _searchController.text = _selectedSymbol!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.show_chart_rounded, color: Color(0xFF6366F1), size: 20),
            SizedBox(width: 8),
            Text(
              'Stock Intelligence',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────────────
          _SearchBar(
            controller: _searchController,
            onSearch: _onSymbolSelected,
          ),

          // ── Quick chips ──────────────────────────────────────────────────
          _QuickSymbolChips(onTap: _onSymbolSelected),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: _selectedSymbol != null
                ? _StockDetailView(symbol: _selectedSymbol!)
                : _TrendingView(onSymbolTap: _onSymbolSelected),
          ),
        ],
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSearch;
  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              decoration: const InputDecoration(
                hintText: 'Search stock symbol (e.g. HDFCBANK)',
                hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: onSearch,
            ),
          ),
          GestureDetector(
            onTap: () => onSearch(controller.text),
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Search',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Symbol Chips ────────────────────────────────────────────────────────

class _QuickSymbolChips extends StatelessWidget {
  final void Function(String) onTap;
  const _QuickSymbolChips({required this.onTap});

  static const _symbols = [
    'HDFCBANK', 'RELIANCE', 'TCS', 'INFY',
    'SBIN', 'TATAMOTORS', 'ICICIBANK', 'WIPRO',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: _symbols
            .map(
              (sym) => GestureDetector(
                onTap: () => onTap(sym),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A2D3E)),
                  ),
                  child: Text(
                    sym,
                    style: const TextStyle(
                      color: Color(0xFF8B8FA8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Trending View ─────────────────────────────────────────────────────────────

class _TrendingView extends ConsumerWidget {
  final void Function(String) onSymbolTap;
  const _TrendingView({required this.onSymbolTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trendingStocksProvider);

    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFF6B7280), size: 48),
            const SizedBox(height: 12),
            const Text(
              'No stock data yet',
              style: TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Stock intelligence updates as\narticles are processed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      ),
      data: (stocks) => stocks.isEmpty
          ? _EmptyTrending()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                const _SectionLabel(
                  icon: Icons.trending_up_rounded,
                  label: 'Trending Stocks by News Activity',
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(height: 10),
                ...stocks.map((s) => _TrendingStockCard(
                      stock: s,
                      onTap: () => onSymbolTap(s.symbol),
                    )),
              ],
            ),
    );
  }
}

class _EmptyTrending extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.show_chart_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Stock Intelligence',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search a stock symbol above\nor wait for news articles to be processed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Trending Stock Card ───────────────────────────────────────────────────────

class _TrendingStockCard extends StatelessWidget {
  final TrendingStock stock;
  final VoidCallback onTap;
  const _TrendingStockCard({required this.stock, required this.onTap});

  Color get _dirColor => switch (stock.latestDirection) {
        'positive' => const Color(0xFF10B981),
        'negative' => const Color(0xFFEF4444),
        _ => const Color(0xFF8B8FA8),
      };

  String get _dirIcon => switch (stock.latestDirection) {
        'positive' => '▲',
        'negative' => '▼',
        _ => '━',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2D3E)),
        ),
        child: Row(
          children: [
            // Ticker
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _dirColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _dirColor.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dirIcon,
                    style: TextStyle(color: _dirColor, fontSize: 12),
                  ),
                  Text(
                    stock.symbol.length > 6
                        ? stock.symbol.substring(0, 6)
                        : stock.symbol,
                    style: TextStyle(
                      color: _dirColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        stock.symbol,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (stock.sector != null && stock.sector!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            stock.sector!,
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (stock.name != null && stock.name!.isNotEmpty)
                    Text(
                      stock.name!,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11),
                    ),
                  if (stock.latestHeadline != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      stock.latestHeadline!,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // News count badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2D3E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${stock.newsCount} news',
                    style: const TextStyle(
                      color: Color(0xFF8B8FA8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF6B7280), size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stock Detail View ─────────────────────────────────────────────────────────

class _StockDetailView extends ConsumerWidget {
  final String symbol;
  const _StockDetailView({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(stockProfileProvider(symbol));
    final newsAsync = ref.watch(stockNewsProvider(symbol));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Profile card
        profileAsync.when(
          loading: () => const SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (profile) => _StockProfileCard(profile: profile),
        ),
        const SizedBox(height: 16),

        // News section header
        const _SectionLabel(
          icon: Icons.article_outlined,
          label: 'News That Affects This Stock',
          color: Color(0xFF94A3B8),
        ),
        const SizedBox(height: 10),

        // News list
        newsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          ),
          error: (_, __) => const _EmptyNews(),
          data: (news) => news.isEmpty
              ? const _EmptyNews()
              : Column(
                  children: news
                      .map((item) => _StockNewsCard(item: item))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

// ── Stock Profile Card ────────────────────────────────────────────────────────

class _StockProfileCard extends StatelessWidget {
  final StockProfile profile;
  const _StockProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF1A1D2E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    profile.symbol.length > 3
                        ? profile.symbol.substring(0, 3)
                        : profile.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.symbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                    ),
                    if (profile.name != null && profile.name != profile.symbol)
                      Text(
                        profile.name!,
                        style: const TextStyle(
                            color: Color(0xFF8B8FA8), fontSize: 12),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (profile.sector != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.3)),
                      ),
                      child: Text(
                        profile.sector!,
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.newsCount} articles',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          if (profile.impactSummary != null &&
              profile.impactSummary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFFFFD700), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.impactSummary!,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (profile.trainingKeywords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: profile.trainingKeywords
                  .take(8)
                  .map(
                    (k) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2D3E),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        k,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stock News Card ───────────────────────────────────────────────────────────

class _StockNewsCard extends StatelessWidget {
  final StockNewsItem item;
  const _StockNewsCard({required this.item});

  Color get _dirColor => switch (item.direction) {
        'positive' => const Color(0xFF10B981),
        'negative' => const Color(0xFFEF4444),
        _ => const Color(0xFF8B8FA8),
      };

  String get _dirText => switch (item.direction) {
        'positive' => '▲ POSITIVE',
        'negative' => '▼ NEGATIVE',
        _ => '━ NEUTRAL',
      };

  Color get _effectColor => switch (item.effect) {
        'high' => const Color(0xFFEF4444),
        'medium' => const Color(0xFFF59E0B),
        _ => const Color(0xFF10B981),
      };

  int get _effectBlocks => switch (item.effect) {
        'high' => 5,
        'medium' => 3,
        _ => 1,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _dirColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _dirColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _dirColor.withOpacity(0.3)),
                ),
                child: Text(
                  _dirText,
                  style: TextStyle(
                    color: _dirColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Effect blocks (mini)
              Row(
                children: List.generate(
                  5,
                  (i) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: i < _effectBlocks
                          ? _effectColor
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.effect.toUpperCase(),
                style: TextStyle(
                  color: _effectColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (item.adminVerified)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          color: Color(0xFF10B981), size: 9),
                      SizedBox(width: 3),
                      Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Headline
          Text(
            item.headline,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          // Reason
          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.reason!,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],

          // Footer
          const SizedBox(height: 8),
          Row(
            children: [
              if (item.source != null) ...[
                const Icon(Icons.source_rounded,
                    color: Color(0xFF6B7280), size: 11),
                const SizedBox(width: 4),
                Text(
                  item.source!,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10),
                ),
                const SizedBox(width: 10),
              ],
              if (item.publishedAt != null)
                Text(
                  _formatDate(item.publishedAt!),
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10),
                ),
              if (item.sector != null && item.sector!.isNotEmpty) ...[
                const Spacer(),
                Text(
                  item.sector!,
                  style: const TextStyle(
                    color: Color(0xFF818CF8),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Empty News ────────────────────────────────────────────────────────────────

class _EmptyNews extends StatelessWidget {
  const _EmptyNews();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.newspaper_rounded,
              color: const Color(0xFF6B7280).withOpacity(0.5), size: 48),
          const SizedBox(height: 12),
          const Text(
            'No news found for this stock',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Articles will appear here as the AI\nprocesses related news.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
