import 'dart:convert';
import 'dart:developer' as developer;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/saved_url.dart';
import 'category_resolver.dart';
import 'category_taxonomy.dart';

// ─── Result types ─────────────────────────────────────────────────────────────

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

  const ChatResponse({required this.intro, required this.sections});
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Wraps the Gemini API for all AI operations in Glimpse.
class GeminiService {
  // Models
  static const _primaryModel = 'gemini-2.5-flash';
  static const _fallbackModel = 'gemini-2.0-flash-lite';

  // Timeouts
  static const _primaryTimeout = Duration(seconds: 20);
  static const _fallbackTimeout = Duration(seconds: 15);
  static const _retryDelay = Duration(milliseconds: 700);

  // Fallback strings — defined once, not scattered across methods
  static const _fallbackQuestion = 'What stands out in my recent saves?';
  static const _fallbackCollectionName = '📁 New collection';
  static const _fallbackDigestSummary = 'Worth revisiting from your saves.';

  static final _jsonConfig = GenerationConfig(
    temperature: 0.2,
    responseMimeType: 'application/json',
  );
  static final _textConfig = GenerationConfig(temperature: 0.4);

  final GenerativeModel _jsonPrimary;
  final GenerativeModel _jsonFallback;
  final GenerativeModel _textPrimary;
  final GenerativeModel _textFallback;

  GeminiService(String apiKey)
    : _jsonPrimary = GenerativeModel(
        model: _primaryModel,
        apiKey: apiKey,
        generationConfig: _jsonConfig,
      ),
      _jsonFallback = GenerativeModel(
        model: _fallbackModel,
        apiKey: apiKey,
        generationConfig: _jsonConfig,
      ),
      _textPrimary = GenerativeModel(
        model: _primaryModel,
        apiKey: apiKey,
        generationConfig: _textConfig,
      ),
      _textFallback = GenerativeModel(
        model: _fallbackModel,
        apiKey: apiKey,
        generationConfig: _textConfig,
      );

  // ─── Core infrastructure ──────────────────────────────────────────────────

  static bool _isRetryable(Object error) {
    final s = error.toString().toLowerCase();
    return s.contains('503') ||
        s.contains('500') ||
        s.contains('overloaded') ||
        s.contains('high demand') ||
        s.contains('unavailable');
  }

  /// Strips markdown code fences from a JSON response string.
  static String _cleanJson(String raw) => raw
      .replaceAll(RegExp(r'```json\s*'), '')
      .replaceAll(RegExp(r'```\s*'), '')
      .trim();

  /// Calls [model] with [prompt], retrying once on retryable errors, with [timeout].
  Future<GenerateContentResponse> _tryModel(
    GenerativeModel model,
    String prompt,
    Duration timeout, {
    required String label,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_retryDelay);
      try {
        return await model
            .generateContent([Content.text(prompt)])
            .timeout(timeout);
      } catch (e) {
        developer.log(
          '$label attempt $attempt failed: $e',
          name: 'GeminiService',
        );
        if (attempt == 0 && _isRetryable(e)) continue;
        rethrow;
      }
    }
    // Dart control-flow requires this but it's unreachable.
    throw StateError('Unreachable');
  }

  /// Tries the primary model, then falls back to the fallback model.
  /// Throws the fallback's error if both fail.
  Future<GenerateContentResponse> _generate({
    required bool jsonMode,
    required String prompt,
  }) async {
    final primary = jsonMode ? _jsonPrimary : _textPrimary;
    final fallback = jsonMode ? _jsonFallback : _textFallback;

    try {
      return await _tryModel(
        primary,
        prompt,
        _primaryTimeout,
        label: 'primary',
      );
    } catch (_) {
      // Primary exhausted — try fallback.
    }

    return _tryModel(fallback, prompt, _fallbackTimeout, label: 'fallback');
  }

  // ─── Categorization ───────────────────────────────────────────────────────

  Future<CategorizationResult> categorize({
    required String title,
    required String description,
    required String url,
  }) async {
    final prompt =
        '''You are a content classifier for a bookmark app. Given the title, description, and URL of a webpage, respond with a JSON object containing exactly these fields:
- "category": choose exactly one category from the allowed list below
- "emoji": use the matching emoji for that category from the allowed list below
- "tags": an array of 3–5 lowercase descriptive keywords for the specific topic
- "summary": 2–3 sentences explaining what this page is about in plain language

Allowed categories:
${CategoryTaxonomy.promptOptions()}

Important rules:
- Keep categories broad and stable.
- Put the specific topic in tags, not the category.
- Examples: React, Flutter, AI agents → category "Technology"; gardening, composting → "Home & Garden"; investing, budgeting → "Finance".
- Summary style (critical): Never start the summary with "This Instagram reel", "This post", "This video", "This article", or "This content". Start directly with what the content is about. Good: "A free NASA data source offering real-time environmental monitoring…" Bad: "This Instagram reel highlights a free NASA data source…"

Title: ${title.isEmpty ? '(not available)' : title}
Description: ${description.isEmpty ? '(not available)' : description}
URL: $url

Output valid JSON only. No markdown, no explanation.''';

    final response = await _generate(jsonMode: true, prompt: prompt);
    return _parseCategorizationResult(response.text ?? '{}');
  }

  CategorizationResult _parseCategorizationResult(String raw) {
    try {
      final data = json.decode(_cleanJson(raw)) as Map<String, dynamic>;

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
    } catch (e, stack) {
      developer.log(
        'Failed to parse categorization result: $e\n$raw',
        name: 'GeminiService',
        stackTrace: stack,
      );
      return const CategorizationResult(
        category: 'Other',
        emoji: '🔖',
        tags: [],
        summary: '',
      );
    }
  }

  // ─── RAG Chat ─────────────────────────────────────────────────────────────

  Future<ChatResponse> chat({
    required String question,
    required List<SavedUrl> contextUrls,
  }) async {
    final contextBlock = contextUrls
        .asMap()
        .entries
        .map((e) {
          final u = e.value;
          return '[${e.key + 1}] ${u.title}\n${u.summary ?? u.description}\nURL: ${u.rawUrl}';
        })
        .join('\n\n');

    final prompt =
        '''You are a personal knowledge assistant. Answer the user's question using ONLY the saved bookmarks provided below.

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
- Do not use markdown, bullet points, asterisks, or numbered lists in any text field.
- Keep sections in ascending sourceIndex order.
- Include one section per relevant bookmark.
- If nothing is relevant, return an empty sections array and explain that in intro.
- Do not output raw URLs — the app renders them separately.

SAVED BOOKMARKS:
$contextBlock

QUESTION: $question''';

    final response = await _generate(jsonMode: true, prompt: prompt);
    return _parseChatResponse(response.text ?? '{}', contextUrls);
  }

  ChatResponse _parseChatResponse(String raw, List<SavedUrl> contextUrls) {
    try {
      final data = json.decode(_cleanJson(raw)) as Map<String, dynamic>;
      final rawSections = data['sections'] as List<dynamic>? ?? const [];

      final sections =
          rawSections
              .whereType<Map<String, dynamic>>()
              .map(
                (map) => ChatResponseSection(
                  sourceIndex: (map['sourceIndex'] as num? ?? 0).toInt(),
                  heading: (map['heading'] as String? ?? 'Saved link').trim(),
                  summary: (map['summary'] as String? ?? '').trim(),
                ),
              )
              .where(
                (s) =>
                    s.sourceIndex > 0 &&
                    s.sourceIndex <= contextUrls.length &&
                    s.summary.isNotEmpty,
              )
              .toList()
            ..sort((a, b) => a.sourceIndex.compareTo(b.sourceIndex));

      return ChatResponse(
        intro:
            (data['intro'] as String? ?? 'Here is what your saved links say.')
                .trim(),
        sections: sections,
      );
    } catch (e, stack) {
      developer.log(
        'Failed to parse chat response: $e\n$raw',
        name: 'GeminiService',
        stackTrace: stack,
      );

      // Best-effort fallback: surface each URL's own summary.
      final fallbackSections = contextUrls
          .asMap()
          .entries
          .map((entry) {
            final u = entry.value;
            return ChatResponseSection(
              sourceIndex: entry.key + 1,
              heading: u.title.isNotEmpty
                  ? u.title
                  : CategoryResolver.displaySourceName(
                      rawUrl: u.rawUrl,
                      fallbackDomain: u.domain,
                    ),
              summary: (u.summary ?? u.description).trim(),
            );
          })
          .where((s) => s.summary.isNotEmpty)
          .toList();

      return ChatResponse(
        intro: 'Here is what your saved links say about that topic.',
        sections: fallbackSections,
      );
    }
  }

  // ─── Multi-link synthesis ─────────────────────────────────────────────────

  Future<String> synthesize({
    required List<SavedUrl> urls,
    String? question,
  }) async {
    final items = urls
        .asMap()
        .entries
        .map((e) {
          final u = e.value;
          return '[${e.key + 1}] ${u.title}\n${u.summary ?? u.description}';
        })
        .join('\n\n');

    final focus = (question?.trim().isNotEmpty ?? false)
        ? '\nFocus on answering: ${question!.trim()}'
        : '';

    final prompt =
        '''Synthesize the key insights from these saved links into a cohesive summary. Identify shared themes, contrasting viewpoints, and the most actionable takeaways.$focus

Cite sources inline using [1], [2], etc.

LINKS:
$items''';

    final response = await _generate(jsonMode: false, prompt: prompt);
    return response.text?.trim() ?? 'No synthesis available.';
  }

  // ─── Translation ──────────────────────────────────────────────────────────

  Future<String> translate({
    required String content,
    required String targetLanguage,
  }) async {
    final prompt =
        'Translate the following into $targetLanguage. Return only the translated text, no explanations or labels.\n\n$content';

    final response = await _generate(jsonMode: false, prompt: prompt);
    return response.text?.trim() ?? content;
  }

  // ─── Weekly recap ─────────────────────────────────────────────────────────

  Future<String> generateRecap(List<SavedUrl> urls) async {
    if (urls.isEmpty) {
      return "You didn't save any links this week. Start building your knowledge base!";
    }

    final byCategory = <String, int>{};
    for (final u in urls) {
      byCategory[u.category] = (byCategory[u.category] ?? 0) + 1;
    }

    final topicsText =
        (byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => '${e.key}: ${e.value} link${e.value > 1 ? 's' : ''}')
            .join(', ');

    final sampleTitles = urls.take(5).map((u) => '- ${u.title}').join('\n');

    final prompt =
        '''You are a friendly personal knowledge assistant. Write a short, encouraging weekly recap for a user who saved ${urls.length} links.

Topics covered: $topicsText

Sample titles:
$sampleTitles

Write 3–5 sentences that highlight their most active topic(s), note any interesting patterns, and encourage them to revisit something. Be warm, concise, and insightful. No bullet points.''';

    final response = await _generate(jsonMode: false, prompt: prompt);
    return response.text?.trim() ??
        'Great week of saving — keep building your knowledge!';
  }

  // ─── Ask suggestions (recent saves) ──────────────────────────────────────

  /// Returns exactly four short questions tailored to the user's recent bookmarks.
  Future<List<String>> generatePersonalAskSuggestions(
    String contextBlock,
  ) async {
    const n = 4;
    final prompt =
        '''You are a personal bookmark assistant called Glimpse.
The user has saved these links recently:

$contextBlock

Generate exactly $n short, specific, conversational questions the user might genuinely want to ask about their saved content.

Rules:
- Reference specific titles, topics, sources, or themes from the list above — do NOT be generic.
- Each question must be under 10 words.
- Write as if the user is asking themselves, not asking "you".
- Do NOT start every question with "Show me" — vary phrasing.
- Do NOT include emoji — emojis are added separately in the app.
- Return valid JSON only: a JSON array of exactly $n strings. No markdown, no explanation.

Good examples:
["What was that discipline post from chilvrs?", "Find the comfort zone article", "Anything about building a second brain?", "What morning routine content did I save?"]

Bad examples:
["Any lifestyle tips saved?", "What's new on Instagram?", "Show me my tech links", "Any new videos?"]''';

    return _parseSuggestions(prompt, n, _fallbackQuestion);
  }

  // ─── Interest clusters ────────────────────────────────────────────────────

  Future<List<Map<String, String>>> nameInterestClusters({
    required String clusterDescriptionsBlock,
    required int clusterCount,
  }) async {
    if (clusterCount <= 0) return const [];

    final prompt =
        '''Here are groups of bookmarks the user has saved, grouped by semantic similarity:

$clusterDescriptionsBlock

For each cluster, assign a JSON object with exactly these keys:
- "label": a short 2-4 word theme name from the actual topics and titles (e.g. "Stoic philosophy", "Watch mods", "Indie dev")
- "summary": one concise sentence describing what this cluster is about

Important:
- Do NOT use a website or app name as the label (e.g. Reddit, YouTube, Instagram) unless the bookmarks are genuinely about that platform. Prefer the subject matter.
- Do NOT include any emoji characters anywhere in your response.

Return valid JSON only: a JSON array of exactly $clusterCount objects in cluster order. No markdown, no explanation.''';

    final response = await _generate(jsonMode: true, prompt: prompt);
    final cleaned = _cleanJson(response.text ?? '[]');

    try {
      final decoded = json.decode(cleaned);
      if (decoded is! List<dynamic>) return _fallbackClusters(clusterCount);

      final out = <Map<String, String>>[];
      for (final e in decoded) {
        if (out.length >= clusterCount) break;
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        out.add({
          'label': m['label']?.toString().trim() ?? 'Cluster',
          'summary': m['summary']?.toString().trim() ?? '',
        });
      }

      // Pad if the model returned fewer than expected.
      while (out.length < clusterCount) {
        out.add(_fallbackCluster(out.length + 1));
      }
      return out;
    } catch (e, stack) {
      developer.log(
        'Failed to parse cluster names: $e',
        name: 'GeminiService',
        stackTrace: stack,
      );
      return _fallbackClusters(clusterCount);
    }
  }

  static Map<String, String> _fallbackCluster(int index) => {
    'label': 'Interest group $index',
    'summary': 'Related bookmarks.',
  };

  static List<Map<String, String>> _fallbackClusters(int count) =>
      List.generate(count, (i) => _fallbackCluster(i + 1));

  // ─── Hierarchical cluster naming (main + sub in one call) ────────────────

  /// Names both top-level clusters and their sub-groups in a single Gemini
  /// call. Returns a list aligned with [mainClusterCount]; each entry has
  /// "label", "summary", and "subLabels" (a List of {"label","summary"} maps).
  Future<List<Map<String, dynamic>>> nameHierarchicalClusters({
    required String descriptionsBlock,
    required int mainClusterCount,
  }) async {
    if (mainClusterCount <= 0) return const [];

    final prompt =
        '''Here are groups of bookmarks the user has saved, grouped by semantic similarity.
Some main clusters also contain sub-groups showing finer-grained topics within them.

$descriptionsBlock

For each main cluster return a JSON object with exactly these keys:
- "label": a short 2-4 word theme name from the actual topics (e.g. "Stoic philosophy", "Watch mods", "Indie dev")
- "summary": one concise sentence describing the cluster
- "subLabels": an array — one object per sub-group listed for that cluster, each with:
  - "label": a 2-4 word sub-topic name that accurately covers EVERY item listed for that sub-group. If the items span multiple regions or topics, choose an umbrella label broad enough to include all of them (e.g. "Indian Mountain Treks" rather than "Himalayan Treks" if the sub-group also contains non-Himalayan Indian destinations like Karnataka or Western Ghats).
  - "summary": one sentence for the sub-group
  If the cluster has no sub-groups listed, return "subLabels": []

Rules:
- Do NOT use a website or app name as the label unless the bookmarks are genuinely about that platform.
- Sub-labels must be more specific than the parent — never repeat the parent label word-for-word.
- Sub-labels must be geographically and thematically accurate for ALL items in the sub-group, not just the majority.
- Do NOT include any emoji anywhere in your response.
- Return valid JSON only: an array of exactly $mainClusterCount objects in cluster order. No markdown, no explanation.''';

    final response = await _generate(jsonMode: true, prompt: prompt);
    final cleaned = _cleanJson(response.text ?? '[]');

    try {
      final decoded = json.decode(cleaned);
      if (decoded is! List<dynamic>) {
        return _fallbackHierarchicalClusters(mainClusterCount);
      }

      final out = <Map<String, dynamic>>[];
      for (final e in decoded) {
        if (out.length >= mainClusterCount) break;
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);

        final rawSubs = m['subLabels'];
        final subLabels = <Map<String, String>>[];
        if (rawSubs is List) {
          for (final s in rawSubs) {
            if (s is! Map) continue;
            subLabels.add({
              'label': s['label']?.toString().trim() ?? '',
              'summary': s['summary']?.toString().trim() ?? '',
            });
          }
        }

        out.add({
          'label': m['label']?.toString().trim() ?? 'Cluster',
          'summary': m['summary']?.toString().trim() ?? '',
          'subLabels': subLabels,
        });
      }

      while (out.length < mainClusterCount) {
        final fb = _fallbackCluster(out.length + 1);
        out.add({...fb, 'subLabels': <Map<String, String>>[]});
      }
      return out;
    } catch (e, stack) {
      developer.log(
        'Failed to parse hierarchical cluster names: $e',
        name: 'GeminiService',
        stackTrace: stack,
      );
      return _fallbackHierarchicalClusters(mainClusterCount);
    }
  }

  static Map<String, dynamic> _fallbackHierarchicalCluster(int index) => {
    'label': 'Interest group $index',
    'summary': 'Related bookmarks.',
    'subLabels': <Map<String, String>>[],
  };

  static List<Map<String, dynamic>> _fallbackHierarchicalClusters(int count) =>
      List.generate(count, (i) => _fallbackHierarchicalCluster(i + 1));

  // ─── Sub-cluster outlier reassignment ─────────────────────────────────────

  /// Given a set of named sub-clusters and the full list of URLs in the parent
  /// cluster, asks Gemini to reassign any URL that clearly belongs to a
  /// different sub-cluster than the one k-means placed it in.
  ///
  /// Returns a map of url-index (0-based into [allUrls]) -> correct
  /// sub-cluster index (0-based into [subClusterLabels]), or an empty map
  /// if no reassignments are needed / the call fails.
  ///
  /// Only URLs that are misassigned are included in the returned map —
  /// URLs absent from the map keep their current sub-cluster assignment.
  Future<Map<int, int>> reassignSubClusterOutliers({
    required List<String> subClusterLabels,
    required List<List<int>> currentAssignments, // subIdx -> list of urlIndices
    required List<String> urlTitles, // indexed by url position
  }) async {
    if (subClusterLabels.length < 2 || urlTitles.isEmpty) return const {};

    // Build a compact block describing the current state.
    final subBlock = subClusterLabels
        .asMap()
        .entries
        .map((e) => '${e.key}: "${e.value}"')
        .join(', ');

    final urlBlock = StringBuffer();
    for (var si = 0; si < currentAssignments.length; si++) {
      for (final ui in currentAssignments[si]) {
        if (ui < 0 || ui >= urlTitles.length) continue;
        final safe = urlTitles[ui].replaceAll('"', "'");
        urlBlock.writeln('  url $ui (currently in sub-cluster $si): "$safe"');
      }
    }

    final prompt =
        '''You are reviewing bookmark sub-cluster assignments that were made by a machine learning algorithm.

Sub-clusters (index: label):
$subBlock

Current URL assignments:
$urlBlock

Identify any URLs whose title contains a clear factual contradiction with the label of the sub-cluster they are assigned to. Focus especially on geographic mismatches — for example, a bookmark about a place in South India (e.g. Karnataka, Western Ghats, Coorg) assigned to a sub-cluster labelled "Himalayan Treks" is a clear mismatch, because Karnataka is not in the Himalayas. Similarly, a European destination assigned to a "New Zealand" sub-cluster is wrong.

Only flag clear factual mismatches. Do not move URLs that are merely thematically adjacent or ambiguous.

Return valid JSON only: an object where each key is the URL index (as a string) and the value is the correct sub-cluster index (as a number).
If no reassignments are needed, return {}.
No markdown, no explanation.''';

    final response = await _generate(jsonMode: true, prompt: prompt);
    final cleaned = _cleanJson(response.text ?? '{}');

    try {
      final decoded = json.decode(cleaned);
      if (decoded is! Map) return const {};

      final result = <int, int>{};
      for (final entry in decoded.entries) {
        final urlIdx = int.tryParse(entry.key.toString());
        final subIdx = (entry.value as num?)?.toInt();
        if (urlIdx == null || subIdx == null) continue;
        if (urlIdx < 0 || urlIdx >= urlTitles.length) continue;
        if (subIdx < 0 || subIdx >= subClusterLabels.length) continue;
        result[urlIdx] = subIdx;
      }
      return result;
    } catch (e, stack) {
      developer.log(
        'Failed to parse sub-cluster reassignments: $e',
        name: 'GeminiService',
        stackTrace: stack,
      );
      return const {};
    }
  }

  // ─── Collection naming ────────────────────────────────────────────────────

  Future<String> suggestCollectionName(List<SavedUrl> urls) async {
    if (urls.isEmpty) return _fallbackCollectionName;

    final titles = urls.take(5).map((u) => '"${u.title}"').join(', ');
    final prompt =
        '''A user is creating a bookmark collection containing these links: $titles
Suggest a short, specific collection name (2-4 words) and one emoji.
Return JSON only: {"name": "...", "emoji": "..."}''';

    final response = await _generate(jsonMode: true, prompt: prompt);

    try {
      final data =
          json.decode(_cleanJson(response.text ?? '{}'))
              as Map<String, dynamic>;
      final name = (data['name'] as String? ?? 'Collection').trim();
      final emoji = (data['emoji'] as String? ?? '📁').trim();
      return '$emoji $name';
    } catch (e, stack) {
      developer.log(
        'Failed to parse collection name: $e',
        name: 'GeminiService',
        stackTrace: stack,
      );
      return _fallbackCollectionName;
    }
  }

  // ─── Digest summaries ─────────────────────────────────────────────────────

  Future<List<String>> summarizeLinksForDigest(List<SavedUrl> links) async {
    if (links.isEmpty) return const [];

    final items = links
        .map((l) {
          final host = Uri.tryParse(l.rawUrl)?.host ?? l.domain;
          final detail = l.description.isNotEmpty
              ? l.description
              : l.tags.join(', ');
          return '- "${l.title}" from $host: $detail';
        })
        .join('\n');

    final prompt =
        '''Summarize each of these saved links in exactly one punchy sentence (max 12 words each).
Make them sound interesting — like a friend recommending something.
Return a JSON array of strings in the same order.

$items''';

    final response = await _generate(jsonMode: true, prompt: prompt);

    try {
      final decoded = json.decode(_cleanJson(response.text ?? '[]'));
      if (decoded is! List<dynamic>) {
        return List.filled(links.length, _fallbackDigestSummary);
      }
      return decoded
          .map((e) => e.toString().trim())
          .take(links.length)
          .toList();
    } catch (e, stack) {
      developer.log(
        'Failed to parse digest summaries: $e',
        name: 'GeminiService',
        stackTrace: stack,
      );
      return List.filled(links.length, _fallbackDigestSummary);
    }
  }

  // ─── Ask suggestions (cluster themes) ────────────────────────────────────

  Future<List<String>> generateAskSuggestionsFromClusterThemes(
    String themeLinesBlock,
  ) async {
    const n = 4;
    final prompt =
        '''You are Glimpse, a personal bookmark assistant.
The user's saved links cluster into these interest themes:

$themeLinesBlock

Generate exactly $n short, natural questions reflecting their genuine recurring interests.
Each question should match the themes above — not random categories from the web.

Rules:
- Under 9 words each.
- Vary the phrasing — don't start every question the same way.
- Do NOT reference specific article titles or author names.
- Do NOT centre questions on a host site (Reddit, YouTube, etc.) — ask about topics.
- Do NOT include emoji.
- Return valid JSON only: a JSON array of exactly $n strings. No markdown, no explanation.

Good examples:
["What have I saved about Himalayan treks?", "Show my AI and SaaS links", "Anything on agribusiness?", "What mindset content did I collect?"]

Bad examples:
["Any Reddit links?", "Show me my links", "What's saved?"]''';

    return _parseSuggestions(prompt, n, _fallbackQuestion);
  }

  // ─── Shared suggestion parser ─────────────────────────────────────────────

  Future<List<String>> _parseSuggestions(
    String prompt,
    int n,
    String fallback,
  ) async {
    final response = await _generate(jsonMode: true, prompt: prompt);

    try {
      final decoded = json.decode(_cleanJson(response.text ?? '[]'));
      if (decoded is! List<dynamic>) return List.filled(n, fallback);

      final out = decoded
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .take(n)
          .toList();

      // Pad to exactly n if the model returned fewer.
      while (out.length < n) out.add(fallback);
      return out;
    } catch (e, stack) {
      developer.log(
        'Failed to parse suggestions: $e',
        name: 'GeminiService',
        stackTrace: stack,
      );
      return List.filled(n, fallback);
    }
  }
}
