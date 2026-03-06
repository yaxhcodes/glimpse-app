/// Response model for Claude categorization results.
class CategorizationResult {
  final String category;
  final String emoji;
  final List<String> tags;

  const CategorizationResult({
    required this.category,
    required this.emoji,
    required this.tags,
  });

  factory CategorizationResult.fromJson(Map<String, dynamic> json) {
    return CategorizationResult(
      category: json['category'] as String? ?? 'Uncategorized',
      emoji: json['emoji'] as String? ?? '📎',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Fallback result when LLM is unavailable.
  factory CategorizationResult.uncategorized() {
    return const CategorizationResult(
      category: 'Uncategorized',
      emoji: '📎',
      tags: [],
    );
  }
}
