import 'dart:convert';
import 'dart:developer' as developer;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/saved_url.dart';
import 'category_resolver.dart';
import 'category_taxonomy.dart';

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

class ChatResponseSection {
  final int sourceIndex;
  final String heading;
  final String summary;

  const ChatResponseSection({
    required this.sourceIndex,
    required this.heading,
    required this.summary,
  });
}

class ChatResponse {
  final String intro;
  final List<ChatResponseSection> sections;

  const ChatResponse({
    required this.intro,
    required this.sections,
  });
}

/// Wraps the Gemini Flash API for all AI operations in Glimpse.
class GeminiService {
  static const _primaryModelName = 'gemini-2.5-flash';
  static const _fallbackModelName = 'gemini-2.0-flash-lite';
  static final _jsonGenerationConfig = GenerationConfig(
    temperature: 0.2,
    responseMimeType: 'application/json',
  );
  static final _textGenerationConfig = GenerationConfig(
    temperature: 0.4,
  );

  // JSON output model — structured categorization responses
  final GenerativeModel _jsonModel;

  final GenerativeModel _jsonFallbackModel;

  // Plain text model — chat, synthesis, translation, recap
  final GenerativeModel _textModel;

  final GenerativeModel _textFallbackModel;

  GeminiService(String apiKey)
      : _jsonModel = GenerativeModel(
          model: _primaryModelName,
          apiKey: apiKey,
          generationConfig: _jsonGenerationConfig,
        ),
        _jsonFallbackModel = GenerativeModel(
          model: _fallbackModelName,
          apiKey: apiKey,
          generationConfig: _jsonGenerationConfig,
        ),
        _textModel = GenerativeModel(
          model: _primaryModelName,
          apiKey: apiKey,
          generationConfig: _textGenerationConfig,
        ),
        _textFallbackModel = GenerativeModel(
          model: _fallbackModelName,
          apiKey: apiKey,
          generationConfig: _textGenerationConfig,
        );

  bool _isRetryableModelError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('503') ||
        text.contains('500') ||
        text.contains('overloaded') ||
        text.contains('high demand') ||
        text.contains('unavailable');
  }

  Future<GenerateContentResponse> _generateWithFallback({
    required GenerativeModel primaryModel,
    required GenerativeModel fallbackModel,
    required String prompt,
  }) async {
    // Try primary model with one retry
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      try {
        return await primaryModel.generateContent([Content.text(prompt)]);
      } catch (error) {
        developer.log('Gemini primary attempt $attempt failed: $error',
            name: 'GeminiService');
        if (attempt == 0 && _isRetryableModelError(error)) continue;
        // Primary exhausted — fall through to fallback
        break;
      }
    }

    // Try fallback model with one retry
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      try {
        return await fallbackModel.generateContent([Content.text(prompt)]);
      } catch (error) {
        developer.log('Gemini fallback attempt $attempt failed: $error',
            name: 'GeminiService');
        if (attempt == 0 && _isRetryableModelError(error)) continue;
        throw error;
      }
    }

    throw Exception('Gemini request failed after all attempts');
  }

  // ─── Categorization ────────────────────────────────────────────────────────

  /// Classifies a URL and generates a category, emoji, tags, and 2-3 sentence summary.
  Future<CategorizationResult> categorize({
    required String title,
    required String description,
    required String url,
  }) async {
    final prompt = '''You are a content classifier for a bookmark app. Given the title, description, and URL of a webpage, respond with a JSON object containing exactly these fields:
- "category": choose exactly one category from the allowed list below
- "emoji": use the matching emoji for that category from the allowed list below
- "tags": an array of 3–5 lowercase descriptive keywords for the specific topic
- "summary": 2–3 sentences explaining what this page is about in plain language

Allowed categories:
${CategoryTaxonomy.promptOptions()}

Important rules:
- Keep categories broad and stable.
- Put the specific topic in tags, not in category.
- Example: React, Flutter, AI agents, or databases should usually be category "Technology" and appear as tags.
- Example: gardening, composting, balcony farming should usually be category "Home & Garden" and appear as tags.
- Example: investing, stocks, budgeting should usually be category "Finance" and appear as tags.

Title: ${title.isEmpty ? '(not available)' : title}
Description: ${description.isEmpty ? '(not available)' : description}
URL: $url

Output valid JSON only. No markdown, no explanation.''';

    final response = await _generateWithFallback(
      primaryModel: _jsonModel,
      fallbackModel: _jsonFallbackModel,
      prompt: prompt,
    );
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
          ? rawTags
              .map((t) => t.toString().trim().toLowerCase())
              .where((t) => t.isNotEmpty)
              .toSet()
              .take(5)
              .toList()
          : <String>[];

      final normalized = CategoryTaxonomy.normalize(
        category: (data['category'] as String? ?? 'Other').trim(),
        emoji: (data['emoji'] as String?)?.trim(),
        tags: tags,
      );

      return CategorizationResult(
        category: normalized.name,
        emoji: normalized.emoji,
        tags: tags,
        summary: (data['summary'] as String? ?? '').trim(),
      );
    } catch (_) {
      return const CategorizationResult(
        category: 'Other',
        emoji: '🔖',
        tags: [],
        summary: '',
      );
    }
  }

  // ─── Ask Your Bookmarks (RAG chat) ──────────────────────────────────────────

  /// Answers a question using saved URLs as context.
  /// [contextUrls] should be the top-K semantically similar URLs.
  Future<ChatResponse> chat({
    required String question,
    required List<SavedUrl> contextUrls,
  }) async {
    final contextBlock = contextUrls.asMap().entries.map((e) {
      final u = e.value;
      return '[${e.key + 1}] ${u.title}\n${u.summary ?? u.description}\nURL: ${u.rawUrl}';
    }).join('\n\n');

    final prompt = '''You are a personal knowledge assistant. Answer the user's question using ONLY the saved bookmarks provided below.

Return valid JSON only with this exact shape:
{
  "intro": "one short sentence that introduces the answer",
  "sections": [
    {
      "sourceIndex": 1,
      "heading": "short heading for this source",
      "summary": "2-4 sentences describing what this specific source says about the question"
    }
  ]
}

Rules:
- Do not use markdown.
- Do not use bullet points, asterisks, or numbered lists in the text.
- Keep sections in ascending sourceIndex order.
- Each section must correspond to one saved bookmark.
- If multiple bookmarks are relevant, include one section per relevant bookmark.
- If nothing is relevant, return an empty sections array and explain that in intro.
- Do not output raw URLs because the app renders them separately.

SAVED BOOKMARKS:
$contextBlock

QUESTION: $question''';

    final response = await _generateWithFallback(
      primaryModel: _jsonModel,
      fallbackModel: _jsonFallbackModel,
      prompt: prompt,
    );
    final text = response.text ?? '{}';
    return _parseChatResponse(text, contextUrls);
  }

  ChatResponse _parseChatResponse(String jsonText, List<SavedUrl> contextUrls) {
    try {
      final cleaned = jsonText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final data = json.decode(cleaned) as Map<String, dynamic>;
      final rawSections = data['sections'] as List<dynamic>? ?? const [];

      final sections = rawSections
          .map((item) {
            final map = item as Map<String, dynamic>;
            return ChatResponseSection(
              sourceIndex: (map['sourceIndex'] as num? ?? 0).toInt(),
              heading: (map['heading'] as String? ?? 'Saved link').trim(),
              summary: (map['summary'] as String? ?? '').trim(),
            );
          })
          .where((item) =>
              item.sourceIndex > 0 &&
              item.sourceIndex <= contextUrls.length &&
              item.summary.isNotEmpty)
          .toList()
        ..sort((a, b) => a.sourceIndex.compareTo(b.sourceIndex));

      return ChatResponse(
        intro: (data['intro'] as String? ?? 'Here is what your saved links say.').trim(),
        sections: sections,
      );
    } catch (_) {
      final fallbackSections = contextUrls.asMap().entries.map((entry) {
        final url = entry.value;
        return ChatResponseSection(
          sourceIndex: entry.key + 1,
          heading: url.title.isNotEmpty
              ? url.title
              : CategoryResolver.displaySourceName(
                  rawUrl: url.rawUrl,
                  fallbackDomain: url.domain,
                ),
          summary: (url.summary ?? url.description).trim(),
        );
      }).where((item) => item.summary.isNotEmpty).toList();

      return ChatResponse(
        intro: 'Here is what your saved links say about that topic.',
        sections: fallbackSections,
      );
    }
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

    final response = await _generateWithFallback(
      primaryModel: _textModel,
      fallbackModel: _textFallbackModel,
      prompt: prompt,
    );
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

    final response = await _generateWithFallback(
      primaryModel: _textModel,
      fallbackModel: _textFallbackModel,
      prompt: prompt,
    );
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

    final response = await _generateWithFallback(
      primaryModel: _textModel,
      fallbackModel: _textFallbackModel,
      prompt: prompt,
    );
    return response.text?.trim() ?? 'Great week of saving — keep building your knowledge!';
  }
}
