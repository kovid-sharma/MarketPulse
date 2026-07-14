// StockProfile model matching backend /users/stocks/{symbol} response

class StockProfile {
  final String symbol;
  final String? name;
  final String? sector;
  final String? impactSummary;
  final List<String> trainingKeywords;
  final int newsCount;
  final DateTime? lastTrainedAt;

  const StockProfile({
    required this.symbol,
    this.name,
    this.sector,
    this.impactSummary,
    this.trainingKeywords = const [],
    this.newsCount = 0,
    this.lastTrainedAt,
  });

  factory StockProfile.fromJson(Map<String, dynamic> json) {
    return StockProfile(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String?,
      sector: json['sector'] as String?,
      impactSummary: json['impact_summary'] as String?,
      trainingKeywords: (json['training_keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      newsCount: (json['news_count'] as num?)?.toInt() ?? 0,
      lastTrainedAt: json['last_trained_at'] != null
          ? DateTime.tryParse(json['last_trained_at'] as String)
          : null,
    );
  }
}

class StockNewsItem {
  final String articleId;
  final String headline;
  final String? summary;
  final String? contentSnippet;
  final String? sector;
  final String direction; // positive | negative | neutral
  final String effect; // high | medium | low
  final String? reason;
  final String sentiment; // bullish | bearish | neutral
  final DateTime? publishedAt;
  final bool adminVerified;
  final String? source;
  final String? url;

  const StockNewsItem({
    required this.articleId,
    required this.headline,
    this.summary,
    this.contentSnippet,
    this.sector,
    required this.direction,
    required this.effect,
    this.reason,
    required this.sentiment,
    this.publishedAt,
    this.adminVerified = false,
    this.source,
    this.url,
  });

  factory StockNewsItem.fromJson(Map<String, dynamic> json) {
    final direction = json['direction'] as String? ?? 'neutral';
    final effect = json['effect'] as String? ?? 'medium';
    final sentiment = json['sentiment'] as String? ?? 'neutral';
    return StockNewsItem(
      articleId: json['article_id'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      summary: json['summary'] as String?,
      contentSnippet: json['content_snippet'] as String?,
      sector: json['sector'] as String?,
      direction: ['positive', 'negative', 'neutral'].contains(direction)
          ? direction
          : 'neutral',
      effect: ['high', 'medium', 'low'].contains(effect) ? effect : 'medium',
      reason: json['reason'] as String?,
      sentiment: ['bullish', 'bearish', 'neutral'].contains(sentiment)
          ? sentiment
          : 'neutral',
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      adminVerified: json['admin_verified'] as bool? ?? false,
      source: json['source'] as String?,
      url: json['url'] as String?,
    );
  }
}

class TrendingStock {
  final String symbol;
  final String? name;
  final String? sector;
  final int newsCount;
  final String latestDirection;
  final String latestSentiment;
  final String? latestHeadline;

  const TrendingStock({
    required this.symbol,
    this.name,
    this.sector,
    required this.newsCount,
    required this.latestDirection,
    required this.latestSentiment,
    this.latestHeadline,
  });

  factory TrendingStock.fromJson(Map<String, dynamic> json) {
    return TrendingStock(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String?,
      sector: json['sector'] as String?,
      newsCount: (json['news_count'] as num?)?.toInt() ?? 0,
      latestDirection: json['latest_direction'] as String? ?? 'neutral',
      latestSentiment: json['latest_sentiment'] as String? ?? 'neutral',
      latestHeadline: json['latest_headline'] as String?,
    );
  }
}
