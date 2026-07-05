// Article model matching backend ArticleOut schema

class StockImpact {
  final String symbol;
  final String? name;
  final String? sector;
  final String direction; // positive | negative | neutral
  final String effect; // high | medium | low
  final String? reason;

  const StockImpact({
    required this.symbol,
    this.name,
    this.sector,
    required this.direction,
    required this.effect,
    this.reason,
  });

  factory StockImpact.fromJson(Map<String, dynamic> json) {
    final effect = json['effect'] as String? ?? 'low';
    final direction = json['direction'] as String? ?? 'neutral';
    return StockImpact(
      symbol: (json['symbol'] as String? ?? '').toUpperCase().trim(),
      name: json['name'] as String?,
      sector: json['sector'] as String?,
      direction: ['positive', 'negative', 'neutral'].contains(direction)
          ? direction
          : 'neutral',
      effect: ['high', 'medium', 'low'].contains(effect) ? effect : 'low',
      reason: json['reason'] as String?,
    );
  }
}

class Article {
  final String id;
  final String headline;
  final String? content;
  final String? source;
  final String? url;
  final DateTime? publishedAt;
  final DateTime fetchedAt;
  final bool? isFinanciallyRelevant;
  final bool needsReview;
  final String aiStatus;
  final String? credibility;
  final String? geography;
  final double? classificationConfidence;
  final List<Map<String, dynamic>>? impacts;
  final String? summary;
  final String? context;
  final String? impactExplanation;
  final String? keyTakeaway;
  final String? sentiment;
  final List<String> marketsAffected;
  final String? tradeLogic;

  const Article({
    required this.id,
    required this.headline,
    this.content,
    this.source,
    this.url,
    this.publishedAt,
    required this.fetchedAt,
    this.isFinanciallyRelevant,
    required this.needsReview,
    required this.aiStatus,
    this.credibility,
    this.geography,
    this.classificationConfidence,
    this.impacts,
    this.summary,
    this.context,
    this.impactExplanation,
    this.keyTakeaway,
    this.sentiment,
    this.marketsAffected = const [],
    this.tradeLogic,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      headline: json['headline'] as String,
      content: json['content'] as String?,
      source: json['source'] as String?,
      url: json['url'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      isFinanciallyRelevant: json['is_financially_relevant'] as bool?,
      needsReview: json['needs_review'] as bool? ?? false,
      aiStatus: json['ai_status'] as String? ?? 'pending',
      credibility: json['credibility'] as String?,
      geography: json['geography'] as String?,
      classificationConfidence:
          (json['classification_confidence'] as num?)?.toDouble(),
      impacts: (json['impacts'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      summary: json['summary'] as String?,
      context: json['context'] as String?,
      impactExplanation: json['impact_explanation'] as String?,
      keyTakeaway: json['key_takeaway'] as String?,
      sentiment: json['sentiment'] as String?,
      marketsAffected: (json['markets_affected'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tradeLogic: json['trade_logic'] as String?,
    );
  }

  /// Returns structured StockImpact objects from the impacts JSON
  List<StockImpact> get stockImpacts {
    if (impacts == null) return [];
    final seen = <String>{};
    final result = <StockImpact>[];
    for (final imp in impacts!) {
      final symbol = (imp['symbol'] as String? ?? '').trim().toUpperCase();
      if (symbol.isNotEmpty && !seen.contains(symbol)) {
        seen.add(symbol);
        result.add(StockImpact.fromJson(imp));
      }
    }
    return result;
  }

  /// Fallback: unique stock symbols from old-style impacts
  List<String> get affectedStocks {
    final si = stockImpacts;
    if (si.isNotEmpty) return si.map((s) => s.symbol).toList();
    if (impacts == null) return [];
    return impacts!
        .expand((i) => (i['stocks'] as List<dynamic>? ?? []).cast<String>())
        .toSet()
        .toList();
  }

  List<String> get sectors {
    if (marketsAffected.isNotEmpty) return marketsAffected;
    if (impacts == null) return [];
    return impacts!
        .map((i) => i['sector'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
