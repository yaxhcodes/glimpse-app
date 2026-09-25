enum AskQueryIntent { find, explain, compare, synthesize, plan }

class AskQueryPlan {
  const AskQueryPlan({
    required this.query,
    this.intent = AskQueryIntent.find,
    this.domain,
    this.collection,
    this.after,
    this.before,
  });

  final String query;
  final AskQueryIntent intent;
  final String? domain;
  final String? collection;
  final DateTime? after;
  final DateTime? before;

  Map<String, dynamic> toJson() => {
    'query': query,
    'intent': intent.name,
    'domain': domain,
    'collection': collection,
    'after': after?.toIso8601String(),
    'before': before?.toIso8601String(),
  };

  factory AskQueryPlan.fromJson(Map<String, dynamic> data, String fallback) {
    String? bounded(Object? raw, int max) =>
        raw is String && raw.trim().isNotEmpty && raw.length <= max
        ? raw.trim()
        : null;
    return AskQueryPlan(
      query: bounded(data['query'], 500) ?? fallback,
      intent:
          AskQueryIntent.values
              .where((v) => v.name == data['intent'])
              .firstOrNull ??
          AskQueryIntent.find,
      domain: bounded(data['domain'], 200),
      collection: bounded(data['collection'], 200),
      after: DateTime.tryParse(data['after']?.toString() ?? ''),
      before: DateTime.tryParse(data['before']?.toString() ?? ''),
    );
  }

  static bool needsPlanning(String question, {required bool hasHistory}) =>
      question.length > 180 ||
      RegExp(
        r'\b(compare|connect|relationship|remember.*but|something.*about|itinerary|plan.*using)\b',
        caseSensitive: false,
      ).hasMatch(question) ||
      (hasHistory && question.trim().split(RegExp(r'\s+')).length < 5);
}
