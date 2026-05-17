import 'dart:convert';
import 'dart:developer' as developer;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/saved_url.dart';
import 'ai_proxy_client.dart';
import 'ai_proxy_config.dart';
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
  final String? proactiveTip;

  const ChatResponse({
    required this.intro,
    required this.sections,
    this.proactiveTip,
  });
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
  static final _jsonConfig = GenerationConfig(
    temperature: 0.2,
    responseMimeType: 'application/json',
  );
  static final _textConfig = GenerationConfig(temperature: 0.4);

  final bool _useProxy;
  final GenerativeModel? _jsonPrimary;
  final GenerativeModel? _jsonFallback;
  final GenerativeModel? _textPrimary;
  final GenerativeModel? _textFallback;

  GeminiService(String apiKey)
    : _useProxy = AiProxyConfig.enabled,
      _jsonPrimary = AiProxyConfig.enabled
          ? null
          : GenerativeModel(
              model: _primaryModel,
              apiKey: apiKey,
              generationConfig: _jsonConfig,
            ),
      _jsonFallback = AiProxyConfig.enabled
          ? null
          : GenerativeModel(
              model: _fallbackModel,
              apiKey: apiKey,
              generationConfig: _jsonConfig,
            ),
      _textPrimary = AiProxyConfig.enabled
          ? null
          : GenerativeModel(
              model: _primaryModel,
              apiKey: apiKey,
              generationConfig: _textConfig,
            ),
      _textFallback = AiProxyConfig.enabled
          ? null
          : GenerativeModel(
              model: _fallbackModel,
              apiKey: apiKey,
              generationConfig: _textConfig,
            );

  // ─── Core infrastructure ──────────────────────────────────────────────────

  static bool _isRetryable(Object error) {
    if (error is AiProxyException) {
      final c = error.statusCode;
      return c == 503 || c == 500 || c == 429;
    }
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
    GenerativeModel? model,
    String prompt,
    Duration timeout, {
    required String label,
  }) async {
    final m = model!;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_retryDelay);
      try {
        return await m
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

  Map<String, dynamic> _generationConfigForProxy(bool jsonMode) {
    return jsonMode
        ? {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          }
        : {
            'temperature': 0.4,
          };
  }

  Future<String> _tryProxyModel({
    required String modelName,
    required String prompt,
    required Map<String, dynamic> generationConfig,
    required Duration timeout,
    required String label,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_retryDelay);
      try {
        final body = <String, dynamic>{
          'model': modelName,
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': generationConfig,
        };
        return await AiProxyClient.instance.postGemini(
          body: body,
          timeout: timeout,
        );
      } catch (e) {
        developer.log(
          '$label proxy attempt $attempt failed: $e',
          name: 'GeminiService',
        );
        if (attempt == 0 && _isRetryable(e)) continue;
        rethrow;
      }
    }
    throw StateError('Unreachable');
  }

  /// Tries the primary model, then falls back to the fallback model.
  /// Returns model text (may be null if empty).
  Future<String?> _generateText({
    required bool jsonMode,
    required String prompt,
  }) async {
    if (_useProxy) {
      final cfg = _generationConfigForProxy(jsonMode);
      try {
        return await _tryProxyModel(
          modelName: _primaryModel,
          prompt: prompt,
          generationConfig: cfg,
          timeout: _primaryTimeout,
          label: 'primary',
        );
      } catch (e) {
        developer.log('Primary proxy model failed, trying fallback: $e',
            name: 'GeminiService');
      }
      return _tryProxyModel(
        modelName: _fallbackModel,
        prompt: prompt,
        generationConfig: cfg,
        timeout: _fallbackTimeout,
        label: 'fallback',
      );
    }

    final primary = jsonMode ? _jsonPrimary! : _textPrimary!;
    final fallback = jsonMode ? _jsonFallback! : _textFallback!;

    try {
      final r = await _tryModel(
        primary,
        prompt,
        _primaryTimeout,
        label: 'primary',
      );
      return r.text;
    } catch (e) {
      developer.log('Primary model failed, trying fallback: $e',
          name: 'GeminiService');
    }

    final r = await _tryModel(
      fallback,
      prompt,
      _fallbackTimeout,
      label: 'fallback',
    );
    return r.text;
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

    final text = await _generateText(jsonMode: true, prompt: prompt);
    return _parseCategorizationResult(text ?? '{}');
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

    final isGreeting = _isGreeting(question);

    final prompt =
        '''You are Glimpse — the user's personal second brain. You have access to their saved links and your job is to give sharp, useful answers that feel like a knowledgeable friend who has read everything they've saved.

RESPONSE RULES:
- Lead with a 1–2 sentence answer that directly addresses the question. Be direct. Never start with "Here are some links" or restate the question.
- Each source gets one punchy sentence max 20 words — what's useful about it, not a description.
- Vary how you refer to saves naturally across responses: "you saved", "from your vault", "you've got", "in your library", etc.
- "proactiveTip": Only include this key if ALL of the following are true:
  (1) The user asked a substantive question — not a greeting, not a one-word message
  (2) 4 or more sources in the context share a single obvious theme
  (3) That theme is clearly different from what the user just asked about
  If any condition fails, omit the "proactiveTip" key entirely from the JSON.
- Never pad. Never use bullet points or markdown in any field.
- Each source may appear at most once per response. If you have already mentioned a source in the sections array, do not reference it again anywhere.
- Tone: concise, warm, slightly informal. Brilliant friend, not a search engine.

Return this exact JSON shape and nothing else:
{
  "intro": "Direct 1-2 sentence answer to the question",
  "sections": [
    {
      "sourceIndex": 1,
      "heading": "2-5 word heading",
      "summary": "One sharp sentence max 20 words on why this source matters"
    }
  ],
  "proactiveTip": "One sentence noticing a pattern, phrased as a question. Omit this key entirely if no strong pattern."
}

Only include sources genuinely relevant to the question. Return valid JSON only. No markdown, no explanation.

SAVED BOOKMARKS:
$contextBlock

QUESTION: $question''';

    final text = await _generateText(jsonMode: true, prompt: prompt);
    return _parseChatResponse(text ?? '{}', contextUrls, isGreeting: isGreeting);
  }

  static bool _isGreeting(String message) {
    final normalized = message.trim().toLowerCase();
    const greetings = {
      'hi', 'hey', 'hello', 'hii', 'hiii', 'yo', 'sup',
      "what's up", 'whats up', 'good morning', 'good evening',
      'good afternoon', 'howdy', 'greetings',
    };
    return greetings.contains(normalized);
  }

  ChatResponse _parseChatResponse(String raw, List<SavedUrl> contextUrls, {bool isGreeting = false}) {
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

      // Deduplicate by sourceIndex so the same source never appears twice.
      final seen = <int>{};
      final deduped = sections.where((s) => seen.add(s.sourceIndex)).toList();

      // Force proactiveTip to null for greetings regardless of model output.
      final rawTip = (data['proactiveTip'] as String?)?.trim();
      final tip = isGreeting ? null : ((rawTip != null && rawTip.isNotEmpty) ? rawTip : null);

      return ChatResponse(
        intro:
            (data['intro'] as String? ?? 'Here is what your saved links say.')
                .trim(),
        sections: deduped,
        proactiveTip: tip,
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

    final text = await _generateText(jsonMode: false, prompt: prompt);
    return text?.trim() ?? 'No synthesis available.';
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

    final text = await _generateText(jsonMode: false, prompt: prompt);
    return text?.trim() ??
        'Great week of saving — keep building your knowledge!';
  }

  // ─── Ask suggestions (recent saves) ──────────────────────────────────────

  /// Returns exactly three short questions tailored to the user's recent bookmarks.
  Future<List<String>> generatePersonalAskSuggestions(
    String contextBlock,
  ) async {
    const n = 3;
    final prompt =
        '''You are a personal bookmark assistant called Glimpse.
The user has saved these links recently:

$contextBlock

Generate exactly $n short, specific questions the user might genuinely want to ask about their saved content.

Rules:
- Reference specific titles, topics, sources, or themes from the list above — do NOT be generic.
- Each question must be 6–8 words max.
- Write as if the user is asking themselves, not asking "you".
- Do NOT start every question with "Show me" — vary phrasing.
- Do NOT include emoji.
- Return valid JSON only: a JSON array of exactly $n strings. No markdown, no explanation.

Good examples:
["What was that discipline post from chilvrs?", "Find the comfort zone article", "Anything about building a second brain?"]

Bad examples:
["Any lifestyle tips saved?", "What's new on Instagram?", "Show me my tech links", "Any new videos?"]''';

    return _parseSuggestions(prompt, n, _fallbackQuestion);
  }

  // ─── Hierarchical cluster naming + outlier correction (single call) ──────

  /// Names top-level clusters and sub-groups AND identifies sub-cluster
  /// outlier reassignments — all in one Gemini call.
  ///
  /// Returns a list aligned with [mainClusterCount]; each entry has:
  ///   "label", "summary", "subLabels" (List of {"label","summary"} maps),
  ///   and "reassignments" (map from url index string to sub-cluster index).
  Future<List<Map<String, dynamic>>> nameHierarchicalClusters({
    required String descriptionsBlock,
    required int mainClusterCount,
  }) async {
    if (mainClusterCount <= 0) return const [];

    final prompt =
        '''Here are groups of bookmarks the user has saved, grouped by semantic similarity.
Some main clusters also contain sub-groups showing finer-grained topics within them.
Each sub-group lists its URLs with an index and title.

$descriptionsBlock

For each main cluster return a JSON object with exactly these keys:
- "label": a short 2-4 word theme name from the actual topics (e.g. "Stoic philosophy", "Watch mods", "Indie dev")
- "summary": one concise sentence describing the cluster
- "subLabels": an array — one object per sub-group listed for that cluster, each with:
  - "label": a 2-4 word sub-topic name that accurately covers EVERY item listed for that sub-group. If the items span multiple regions or topics, choose an umbrella label broad enough to include all of them (e.g. "Indian Mountain Treks" rather than "Himalayan Treks" if the sub-group also contains non-Himalayan Indian destinations like Karnataka or Western Ghats).
  - "summary": one sentence for the sub-group
  If the cluster has no sub-groups listed, return "subLabels": []
- "reassignments": an object mapping URL index (as string key) to the correct sub-group index (as number value) for any URL whose title clearly contradicts the sub-group it was placed in (e.g. geographic mismatches). Only include URLs that need moving. If none need moving, return "reassignments": {}

Rules:
- Do NOT use a website or app name as the label unless the bookmarks are genuinely about that platform.
- Sub-labels must be more specific than the parent — never repeat the parent label word-for-word.
- Sub-labels must be geographically and thematically accurate for ALL items in the sub-group, not just the majority.
- Only flag clear factual mismatches for reassignment, not thematically adjacent URLs.
- Do NOT include any emoji anywhere in your response.
- Return valid JSON only: an array of exactly $mainClusterCount objects in cluster order. No markdown, no explanation.''';

    final text = await _generateText(jsonMode: true, prompt: prompt);
    final cleaned = _cleanJson(text ?? '[]');

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

        final rawReassign = m['reassignments'];
        final reassignments = <String, int>{};
        if (rawReassign is Map) {
          for (final entry in rawReassign.entries) {
            final idx = int.tryParse(entry.key.toString());
            final target = (entry.value as num?)?.toInt();
            if (idx != null && target != null) {
              reassignments[idx.toString()] = target;
            }
          }
        }

        out.add({
          'label': m['label']?.toString().trim() ?? 'Cluster',
          'summary': m['summary']?.toString().trim() ?? '',
          'subLabels': subLabels,
          'reassignments': reassignments,
        });
      }

      while (out.length < mainClusterCount) {
        out.add(_fallbackHierarchicalCluster(out.length + 1));
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
    'reassignments': <String, int>{},
  };

  static List<Map<String, dynamic>> _fallbackHierarchicalClusters(int count) =>
      List.generate(count, (i) => _fallbackHierarchicalCluster(i + 1));

  // ─── Collection naming ────────────────────────────────────────────────────

  Future<String> suggestCollectionName(List<SavedUrl> urls) async {
    if (urls.isEmpty) return _fallbackCollectionName;

    final titles = urls.take(5).map((u) => '"${u.title}"').join(', ');
    final prompt =
        '''A user is creating a bookmark collection containing these links: $titles
Suggest a short, specific collection name (2-4 words) and one emoji.
Return JSON only: {"name": "...", "emoji": "..."}''';

    final text = await _generateText(jsonMode: true, prompt: prompt);

    try {
      final data =
          json.decode(_cleanJson(text ?? '{}'))
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

  // ─── Ask suggestions (cluster themes) ────────────────────────────────────

  Future<List<String>> generateAskSuggestionsFromClusterThemes(
    String themeLinesBlock,
  ) async {
    const n = 3;
    final prompt =
        '''You are Glimpse, a personal bookmark assistant.
The user's saved links cluster into these interest themes:

$themeLinesBlock

Generate exactly $n short, natural questions reflecting their genuine recurring interests.
Each question should match the themes above — not random categories from the web.

Rules:
- 6–8 words max each.
- Vary the phrasing — don't start every question the same way.
- Do NOT reference specific article titles or author names.
- Do NOT centre questions on a host site (Reddit, YouTube, etc.) — ask about topics.
- Do NOT include emoji.
- Return valid JSON only: a JSON array of exactly $n strings. No markdown, no explanation.

Good examples:
["What have I saved about Himalayan treks?", "Show my AI and SaaS links", "Anything on agribusiness?"]

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
    final text = await _generateText(jsonMode: true, prompt: prompt);

    try {
      final decoded = json.decode(_cleanJson(text ?? '[]'));
      if (decoded is! List<dynamic>) return List.filled(n, fallback);

      final out = decoded
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .take(n)
          .toList();

      // Pad to exactly n if the model returned fewer.
      while (out.length < n) {
        out.add(fallback);
      }
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
