import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/saved_url.dart';

/// Result from AI categorization.
class CategorizationResult {
  final String category;
  final String emoji;
  final List<String> tags;
  final String summary;

  const CategorizationResult({
    required this.category,
    required this.emoji,
    required this.tags,
    required this.summary,
  });
}

/// Wraps the Gemini Flash API for all AI operations in Glimpse.
class GeminiService {
  static const _modelName = 'gemini-2.0-flash';

  // JSON output model — structured categorization responses
  final GenerativeModel _jsonModel;

  // Plain text model — chat, synthesis, translation, recap
  final GenerativeModel _textModel;

  GeminiService(String apiKey)
      : _jsonModel = GenerativeModel(
          model: _modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.2,
            responseMimeType: 'application/json',
          ),
        ),
        _textModel = GenerativeModel(
          model: _modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.4,
          ),
        );

  // ─── Categorization ────────────────────────────────────────────────────────

  /// Classifies a URL and generates a category, emoji, tags, and 2-3 sentence summary.
  Future<CategorizationResult> categorize({
    required String title,
    required String description,
    required String url,
  }) async {
    final prompt = '''You are a content classifier for a bookmark app. Given the title, description, and URL of a webpage, respond with a JSON object containing exactly these fields:
- "category": a short topic label in title case (e.g. "Finance", "Gardening", "React", "Solar Energy") — 1 to 3 words
- "emoji": a single emoji that best represents the category
- "tags": an array of 3–5 lowercase descriptive keywords
- "summary": 2–3 sentences explaining what this page is about in plain language

Title: ${title.isEmpty ? '(not available)' : title}
Description: ${description.isEmpty ? '(not available)' : description}
URL: $url

Output valid JSON only. No markdown, no explanation.''';

    final response = await _jsonModel.generateContent([Content.text(prompt)]);
    return _parseCategorizationResult(response.text ?? '{}');
  }

  CategorizationResult _parseCategorizationResult(String jsonText) {
    try {
      final cleaned = jsonText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final data = json.decode(cleaned) as Map<String, dynamic>;

      final rawTags = data['tags'];
      final tags = rawTags is List
          ? rawTags.map((t) => t.toString()).toList()
          : <String>[];

      return CategorizationResult(
        category: (data['category'] as String? ?? 'General').trim(),
        emoji: (data['emoji'] as String? ?? '🔖').trim(),
        tags: tags,
        summary: (data['summary'] as String? ?? '').trim(),
      );
    } catch (_) {
      return const CategorizationResult(
        category: 'General',
        emoji: '🔖',
        tags: [],
        summary: '',
      );
    }
  }

  // ─── Ask Your Bookmarks (RAG chat) ──────────────────────────────────────────

  /// Answers a question using saved URLs as context.
  /// [contextUrls] should be the top-K semantically similar URLs.
  Future<String> chat({
    required String question,
    required List<SavedUrl> contextUrls,
  }) async {
    final contextBlock = contextUrls.asMap().entries.map((e) {
      final u = e.value;
      return '[${e.key + 1}] ${u.title}\n${u.summary ?? u.description}\nURL: ${u.rawUrl}';
    }).join('\n\n');

    final prompt = '''You are a personal knowledge assistant. Answer the user's question using ONLY the saved bookmarks provided below. If the answer is not covered by the bookmarks, say so clearly rather than guessing.

Cite sources inline using [1], [2], etc. List the cited links at the end.

SAVED BOOKMARKS:
$contextBlock

QUESTION: $question''';

    final response = await _textModel.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? 'I could not generate an answer. Please try again.';
  }

  // ─── Multi-Link Synthesis ───────────────────────────────────────────────────

  /// Synthesizes key insights across multiple saved URLs.
  Future<String> synthesize({
    required List<SavedUrl> urls,
    String? question,
  }) async {
    final items = urls.asMap().entries.map((e) {
      final u = e.value;
      return '[${e.key + 1}] ${u.title}\n${u.summary ?? u.description}';
    }).join('\n\n');

    final questionPart = question != null && question.trim().isNotEmpty
        ? '\nFocus on answering: ${question.trim()}'
        : '';

    final prompt = '''Synthesize the key insights from these saved links into a cohesive summary. Identify shared themes, contrasting viewpoints, and the most actionable takeaways.$questionPart

Cite sources inline using [1], [2], etc.

LINKS:
$items''';

    final response = await _textModel.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? 'No synthesis available.';
  }

  // ─── Translation ────────────────────────────────────────────────────────────

  /// Translates text into the specified target language.
  Future<String> translate({
    required String content,
    required String targetLanguage,
  }) async {
    final prompt =
        'Translate the following into $targetLanguage. Return only the translated text, no explanations or labels.\n\n$content';

    final response = await _textModel.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? content;
  }

  // ─── Weekly Recap ───────────────────────────────────────────────────────────

  /// Generates a weekly recap narrative from a list of saved URLs.
  Future<String> generateRecap(List<SavedUrl> urls) async {
    if (urls.isEmpty) {
      return "You didn't save any links this week. Start building your knowledge base!";
    }

    final byCategory = <String, int>{};
    for (final u in urls) {
      byCategory[u.category] = (byCategory[u.category] ?? 0) + 1;
    }

    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topicsText = sorted
        .map((e) => '${e.key}: ${e.value} link${e.value > 1 ? 's' : ''}')
        .join(', ');

    final sampleTitles = urls.take(5).map((u) => '- ${u.title}').join('\n');

    final prompt = '''You are a friendly personal knowledge assistant. Write a short, encouraging weekly recap for a user who saved ${urls.length} links.

Topics covered: $topicsText

Sample titles:
$sampleTitles

Write 3–5 sentences that highlight their most active topic(s), note any interesting patterns, and encourage them to revisit something. Be warm, concise, and insightful. No bullet points.''';

    final response = await _textModel.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? 'Great week of saving — keep building your knowledge!';
  }
}
