// Article model matching backend ArticleOut schema

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
    );
  }

  List<String> get affectedStocks {
    if (impacts == null) return [];
    return impacts!
        .expand((i) => (i['stocks'] as List<dynamic>? ?? []).cast<String>())
        .toSet()
        .toList();
  }

  List<String> get sectors {
    if (impacts == null) return [];
    return impacts!
        .map((i) => i['sector'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
