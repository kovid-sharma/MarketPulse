import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/article.dart';
import '../services/api_client.dart';
import '../widgets/article_card.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

class FeedFilters {
  final String? geography;
  final String? sentiment;
  final String? sector;
  final String? credibility;

  const FeedFilters({
    this.geography,
    this.sentiment,
    this.sector,
    this.credibility,
  });

  FeedFilters copyWith({
    String? geography,
    String? sentiment,
    String? sector,
    String? credibility,
    bool clearGeography = false,
    bool clearSentiment = false,
    bool clearSector = false,
  }) =>
      FeedFilters(
        geography: clearGeography ? null : geography ?? this.geography,
        sentiment: clearSentiment ? null : sentiment ?? this.sentiment,
        sector: clearSector ? null : sector ?? this.sector,
        credibility: credibility ?? this.credibility,
      );
}

final feedFiltersProvider = StateProvider<FeedFilters>((ref) => const FeedFilters());

final feedProvider = FutureProvider.autoDispose<List<Article>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final filters = ref.watch(feedFiltersProvider);
  return client.getFeed(
    geography: filters.geography,
    sentiment: filters.sentiment,
    sector: filters.sector,
    credibility: filters.credibility,
  );
});

// ── Screen ────────────────────────────────────────────────────────────────────

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final filters = ref.watch(feedFiltersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'MarketPulse',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF8B8FA8)),
            onPressed: () => _showFilterSheet(context, ref, filters),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF8B8FA8)),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Active filter chips
          if (filters.geography != null || filters.sentiment != null || filters.sector != null)
            _FilterChipsRow(filters: filters),
          Expanded(
            child: feedAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFF6B7280), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load feed',
                      style: const TextStyle(color: Color(0xFF8B8FA8)),
                    ),
                    TextButton(
                      onPressed: () => ref.refresh(feedProvider),
                      child: const Text('Retry',
                          style: TextStyle(color: Color(0xFF6366F1))),
                    ),
                  ],
                ),
              ),
              data: (articles) => articles.isEmpty
                  ? const Center(
                      child: Text(
                        'No articles found.\nTry adjusting your filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280), height: 1.6),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF6366F1),
                      onRefresh: () async => ref.refresh(feedProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: articles.length,
                        itemBuilder: (ctx, i) => ArticleCard(
                          article: articles[i],
                          onTap: () =>
                              context.push('/article/${articles[i].id}'),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 0),
    );
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, FeedFilters current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(current: current, ref: ref),
    );
  }
}

// ── Filter Chips Row ──────────────────────────────────────────────────────────

class _FilterChipsRow extends ConsumerWidget {
  final FeedFilters filters;
  const _FilterChipsRow({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (filters.geography != null)
            _ActiveChip(
              label: filters.geography!,
              onRemove: () => ref.read(feedFiltersProvider.notifier).update(
                    (s) => s.copyWith(clearGeography: true),
                  ),
            ),
          if (filters.sentiment != null)
            _ActiveChip(
              label: filters.sentiment!,
              onRemove: () => ref.read(feedFiltersProvider.notifier).update(
                    (s) => s.copyWith(clearSentiment: true),
                  ),
            ),
          if (filters.sector != null)
            _ActiveChip(
              label: filters.sector!,
              onRemove: () => ref.read(feedFiltersProvider.notifier).update(
                    (s) => s.copyWith(clearSector: true),
                  ),
            ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: Color(0xFF818CF8), size: 14),
          ),
        ],
      ),
    );
  }
}

// ── Filter Bottom Sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final FeedFilters current;
  final WidgetRef ref;
  const _FilterSheet({required this.current, required this.ref});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _geography;
  String? _sentiment;
  String? _sector;

  @override
  void initState() {
    super.initState();
    _geography = widget.current.geography;
    _sentiment = widget.current.sentiment;
    _sector = widget.current.sector;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Articles',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _FilterSection(
            title: 'Geography',
            options: const ['india', 'global'],
            selected: _geography,
            onSelect: (v) => setState(() => _geography = v == _geography ? null : v),
          ),
          const SizedBox(height: 16),
          _FilterSection(
            title: 'Sentiment',
            options: const ['bullish', 'bearish', 'neutral'],
            selected: _sentiment,
            onSelect: (v) =>
                setState(() => _sentiment = v == _sentiment ? null : v),
          ),
          const SizedBox(height: 16),
          _FilterSection(
            title: 'Sector',
            options: const [
              'banking', 'it', 'pharma', 'fmcg', 'auto', 'realty', 'oil & gas'
            ],
            selected: _sector,
            onSelect: (v) => setState(() => _sector = v == _sector ? null : v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.ref.read(feedFiltersProvider.notifier).state = FeedFilters(
                  geography: _geography,
                  sentiment: _sentiment,
                  sector: _sector,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Apply Filters',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final void Function(String) onSelect;

  const _FilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Color(0xFF8B8FA8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((o) => GestureDetector(
                    onTap: () => onSelect(o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected == o
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF2A2D3E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        o,
                        style: TextStyle(
                          color: selected == o
                              ? Colors.white
                              : const Color(0xFF8B8FA8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────

class _BottomNav extends ConsumerWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13162A),
        border: Border(top: BorderSide(color: Color(0xFF2A2D3E))),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF6B7280),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/feed');
            case 1:
              context.go('/stocks');
            case 2:
              context.go('/notifications');
            case 3:
              context.go('/settings');
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined), label: 'Feed'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded), label: 'Stocks'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
