import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'ai/ai_transport.dart';
import 'tag_noise_filter.dart';
import 'text_cleaner.dart';

bool hasMovieRecommendationIntentForEnrichment(
  Map<String, dynamic> data, {
  required bool hasMovieMentions,
}) {
  final rawIntent = data['memory_intent'];
  final primaryIntent = rawIntent is Map
      ? TextCleaner.cleanLoose(rawIntent['primary_intent']).toLowerCase()
      : TextCleaner.cleanLoose(data['primary_intent']).toLowerCase();
  final recommendationText = [
    data['meaningful_title'],
    data['summary'],
    if (data['topics'] is List) ...(data['topics'] as List),
  ].map(TextCleaner.cleanLoose).join(' ').toLowerCase();
  final hasMovieSubject = RegExp(
    r'\b(movie|movies|film|films|cinema)\b',
  ).hasMatch(recommendationText);
  if (primaryIntent == 'watch_later') {
    return hasMovieMentions || hasMovieSubject;
  }
  final hasExplicitRecommendation = RegExp(
    r'\b(movie|movies|film|films|cinema)\b.{0,40}'
    r'\b(recommend|recommendation|recommendations|watchlist|must watch|to watch)\b|'
    r'\b(recommend|recommendation|recommendations|watchlist|must watch|to watch)\b'
    r'.{0,40}\b(movie|movies|film|films|cinema)\b',
  ).hasMatch(recommendationText);
  return hasMovieMentions && hasExplicitRecommendation;
}

class TranscriptEnrichmentResult {
  const TranscriptEnrichmentResult({
    this.schemaVersion = 1,
    required this.meaningfulTitle,
    required this.summary,
    required this.category,
    required this.tags,
    this.contentType = 'generic',
    this.brief,
    this.steps = const [],
    this.mentions = const [],
    this.notableItems = const [],
    this.contentSections = const [],
    this.recipe,
    this.keyPoints = const [],
    this.categoryEvidence,
    this.categoryConfidence,
    this.topics = const [],
    this.categoryNeedsReview = false,
    this.originalGeminiCategory,
    this.thumbnailUrl,
    this.creator,
    this.caption,
    this.transcript,
    this.ocrText,
    this.likeCount,
    this.commentCount,
    this.imageUrls = const [],
    this.firstComment,
    this.latestComments = const [],
    this.memoryIntent,
  });

  final int schemaVersion;
  final String meaningfulTitle;
  final String summary;
  final String category;
  final List<String> tags;
  final String contentType;
  final String? brief;
  final List<EnrichedContentStep> steps;
  final List<EnrichedMention> mentions;
  final List<EnrichedNotableItem> notableItems;
  final List<EnrichedContentSection> contentSections;
  final EnrichedRecipe? recipe;
  final List<String> keyPoints;
  final String? categoryEvidence;
  final double? categoryConfidence;
  final List<String> topics;
  final bool categoryNeedsReview;
  final String? originalGeminiCategory;
  final String? thumbnailUrl;
  final String? creator;
  final String? caption;
  final String? transcript;
  final String? ocrText;
  final int? likeCount;
  final int? commentCount;
  final List<String> imageUrls;
  final String? firstComment;
  final List<String> latestComments;
  final MemoryIntentMetadata? memoryIntent;

  bool get hasUsefulContent =>
      meaningfulTitle.trim().isNotEmpty ||
      summary.trim().isNotEmpty ||
      (brief?.trim().isNotEmpty ?? false) ||
      tags.isNotEmpty ||
      steps.isNotEmpty ||
      mentions.isNotEmpty ||
      notableItems.isNotEmpty ||
      contentSections.isNotEmpty ||
      (recipe?.hasUsefulContent ?? false) ||
      (transcript?.trim().isNotEmpty ?? false) ||
      (ocrText?.trim().isNotEmpty ?? false);

  bool get hasReliableMediaEvidence =>
      _isMeaningfulEvidence(transcript, minChars: 80, minWords: 12) ||
      (caption?.trim().isNotEmpty ?? false) ||
      _isMeaningfulEvidence(ocrText, minChars: 40, minWords: 6) ||
      (creator?.trim().isNotEmpty == true &&
          thumbnailUrl?.trim().isNotEmpty == true) ||
      imageUrls.isNotEmpty ||
      (firstComment?.trim().isNotEmpty ?? false) ||
      mentions.isNotEmpty ||
      (recipe?.ingredients.isNotEmpty == true) ||
      (recipe?.steps.isNotEmpty == true);

  bool get hasStructuredEnrichment {
    if (mentions.isNotEmpty ||
        steps.isNotEmpty ||
        notableItems.isNotEmpty ||
        contentSections.isNotEmpty ||
        keyPoints.isNotEmpty ||
        (recipe?.hasUsefulContent ?? false)) {
      return true;
    }
    final cleanedSummary = summary.trim();
    if (!_isMeaningfulEvidence(cleanedSummary, minChars: 40, minWords: 8)) {
      return false;
    }
    final rawEvidence = [caption, transcript, ocrText]
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) {
          return item.isNotEmpty;
        });
    for (final evidence in rawEvidence) {
      if (_sameLooseText(cleanedSummary, evidence)) return false;
    }
    return tags.isNotEmpty;
  }

  TranscriptEnrichmentResult copyWith({
    int? schemaVersion,
    String? meaningfulTitle,
    String? summary,
    String? category,
    List<String>? tags,
    String? contentType,
    String? brief,
    List<EnrichedContentStep>? steps,
    List<EnrichedMention>? mentions,
    List<EnrichedNotableItem>? notableItems,
    List<EnrichedContentSection>? contentSections,
    EnrichedRecipe? recipe,
    List<String>? keyPoints,
    String? categoryEvidence,
    double? categoryConfidence,
    List<String>? topics,
    bool? categoryNeedsReview,
    String? originalGeminiCategory,
    String? thumbnailUrl,
    String? creator,
    String? caption,
    String? transcript,
    String? ocrText,
    int? likeCount,
    int? commentCount,
    List<String>? imageUrls,
    String? firstComment,
    List<String>? latestComments,
    MemoryIntentMetadata? memoryIntent,
  }) {
    return TranscriptEnrichmentResult(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      meaningfulTitle: meaningfulTitle ?? this.meaningfulTitle,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      contentType: contentType ?? this.contentType,
      brief: brief ?? this.brief,
      steps: steps ?? this.steps,
      mentions: mentions ?? this.mentions,
      notableItems: notableItems ?? this.notableItems,
      contentSections: contentSections ?? this.contentSections,
      recipe: recipe ?? this.recipe,
      keyPoints: keyPoints ?? this.keyPoints,
      categoryEvidence: categoryEvidence ?? this.categoryEvidence,
      categoryConfidence: categoryConfidence ?? this.categoryConfidence,
      topics: topics ?? this.topics,
      categoryNeedsReview: categoryNeedsReview ?? this.categoryNeedsReview,
      originalGeminiCategory:
          originalGeminiCategory ?? this.originalGeminiCategory,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      creator: creator ?? this.creator,
      caption: caption ?? this.caption,
      transcript: transcript ?? this.transcript,
      ocrText: ocrText ?? this.ocrText,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      imageUrls: imageUrls ?? this.imageUrls,
      firstComment: firstComment ?? this.firstComment,
      latestComments: latestComments ?? this.latestComments,
      memoryIntent: memoryIntent ?? this.memoryIntent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'meaningful_title': meaningfulTitle,
      'summary': summary,
      'category': category,
      'tags': tags,
      'content_type': contentType,
      'brief': brief,
      'steps': steps.map((item) => item.toJson()).toList(),
      'mentions': mentions.map((item) => item.toJson()).toList(),
      'notable_items': notableItems.map((item) => item.toJson()).toList(),
      'content_sections': contentSections
          .map((section) => section.toJson())
          .toList(),
      'recipe': recipe?.toJson(),
      'key_points': keyPoints,
      'category_evidence': categoryEvidence,
      'category_confidence': categoryConfidence,
      'topics': topics,
      'category_needs_review': categoryNeedsReview,
      'original_gemini_category': originalGeminiCategory,
      'thumbnail_url': thumbnailUrl,
      'creator': creator,
      'caption': caption,
      'transcript': transcript,
      'ocr_text': ocrText,
      'like_count': likeCount,
      'comment_count': commentCount,
      'image_urls': imageUrls,
      'first_comment': firstComment,
      'latest_comments': latestComments,
      'memory_intent': memoryIntent?.toJson(),
    };
  }

  static TranscriptEnrichmentResult? fromJson(Map<String, dynamic> json) {
    return TranscriptEnrichmentResult(
      schemaVersion:
          TranscriptEnrichmentService._extractPositiveInt(
            json['schema_version'] ?? json['schemaVersion'],
          ) ??
          1,
      meaningfulTitle: TranscriptEnrichmentService._cleanText(
        json['meaningful_title'],
      ),
      summary: TranscriptEnrichmentService._cleanText(json['summary']),
      category: TranscriptEnrichmentService._cleanText(json['category']),
      tags: TagNoiseFilter.filterTags(
        TranscriptEnrichmentService._extractStringList(json['tags']),
      ),
      contentType: TranscriptEnrichmentService._contentTypeFromJson(json),
      brief: TranscriptEnrichmentService._cleanNullableText(
        json['brief'] ??
            json['short_description'] ??
            json['content_description'],
      ),
      steps: TranscriptEnrichmentService._extractContentSteps(json),
      mentions: TranscriptEnrichmentService._extractMentions(json),
      notableItems: TranscriptEnrichmentService._extractNotableItems(json),
      contentSections: TranscriptEnrichmentService._extractContentSections(
        json,
      ),
      recipe: EnrichedRecipe.fromJsonOrNull(json['recipe']),
      keyPoints: TranscriptEnrichmentService._extractStringList(
        json['key_points'],
      ),
      categoryEvidence: TranscriptEnrichmentService._cleanNullableText(
        json['category_evidence'] ?? json['domain_evidence'],
      ),
      categoryConfidence: TranscriptEnrichmentService._toDouble(
        json['category_confidence'] ??
            json['domain_confidence'] ??
            json['confidence'],
      ),
      topics: TranscriptEnrichmentService._extractStringList(json['topics']),
      categoryNeedsReview:
          json['category_needs_review'] == true ||
          json['domain_needs_review'] == true,
      originalGeminiCategory: TranscriptEnrichmentService._cleanNullableText(
        json['original_gemini_category'] ?? json['original_gemini_domain'],
      ),
      thumbnailUrl: TranscriptEnrichmentService._cleanNullableText(
        json['thumbnail_url'],
      ),
      creator: TranscriptEnrichmentService._cleanNullableText(json['creator']),
      caption: TranscriptEnrichmentService._cleanNullableText(json['caption']),
      transcript: TranscriptEnrichmentService._cleanNullableText(
        json['transcript'],
      ),
      ocrText: TranscriptEnrichmentService._cleanNullableText(
        json['ocr_text'] ?? json['ocrText'],
      ),
      likeCount: TranscriptEnrichmentService._extractPositiveInt(
        json['like_count'],
      ),
      commentCount: TranscriptEnrichmentService._extractPositiveInt(
        json['comment_count'],
      ),
      imageUrls: TranscriptEnrichmentService._extractStringList(
        json['image_urls'] ?? json['imageUrls'] ?? json['images'],
      ),
      firstComment: TranscriptEnrichmentService._cleanNullableText(
        json['first_comment'] ?? json['firstComment'],
      ),
      latestComments: TranscriptEnrichmentService._extractStringList(
        json['latest_comments'] ?? json['latestComments'],
      ),
      memoryIntent: MemoryIntentMetadata.fromJsonOrNull(
        json['memory_intent'] ?? json,
      ),
    );
  }

  static bool _isMeaningfulEvidence(
    String? raw, {
    required int minChars,
    required int minWords,
  }) {
    final text = raw?.trim() ?? '';
    if (text.length < minChars) return false;
    if (RegExp(
      r'unable to generate transcript|no transcript available|transcript unavailable|failed to extract|extraction failed|not available|undefined|null',
      caseSensitive: false,
    ).hasMatch(text)) {
      return false;
    }
    final words = text
        .split(RegExp(r'[^a-z0-9]+', caseSensitive: false))
        .where((word) => word.length >= 2)
        .length;
    return words >= minWords;
  }

  static bool _sameLooseText(String a, String b) {
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final left = normalize(a);
    final right = normalize(b);
    if (left.isEmpty || right.isEmpty) return false;
    return left == right ||
        (right.length > 80 && left.length > 80 && right.startsWith(left)) ||
        (left.length > 80 && right.length > 80 && left.startsWith(right));
  }
}

class TranscriptEnrichmentException implements Exception {
  const TranscriptEnrichmentException(
    this.message, {
    this.statusCode,
    this.retryable = true,
  });

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() =>
      'TranscriptEnrichmentException($message'
      '${statusCode != null ? ', status=$statusCode' : ''})';
}

class MemoryIntentMetadata {
  const MemoryIntentMetadata({
    required this.primaryIntent,
    this.secondaryIntents = const [],
    this.intentConfidence,
    this.lifeArea,
    this.whySavedHypothesis,
    this.actionability,
    this.timeHorizon,
    this.effortLevel,
    this.costLevel,
    this.difficulty,
    this.skillLevel,
    this.location,
    this.timeRequired,
    this.freshnessSensitivity,
    this.evergreenScore,
  });

  final String primaryIntent;
  final List<String> secondaryIntents;
  final double? intentConfidence;
  final String? lifeArea;
  final String? whySavedHypothesis;
  final String? actionability;
  final String? timeHorizon;
  final String? effortLevel;
  final String? costLevel;
  final String? difficulty;
  final String? skillLevel;
  final String? location;
  final String? timeRequired;
  final String? freshnessSensitivity;
  final double? evergreenScore;

  bool get hasUsefulContent =>
      primaryIntent.trim().isNotEmpty ||
      secondaryIntents.isNotEmpty ||
      (lifeArea?.trim().isNotEmpty ?? false) ||
      (whySavedHypothesis?.trim().isNotEmpty ?? false);

  Map<String, dynamic> toJson() {
    return {
      'primary_intent': primaryIntent,
      'secondary_intents': secondaryIntents,
      'intent_confidence': intentConfidence,
      'life_area': lifeArea,
      'why_saved_hypothesis': whySavedHypothesis,
      'actionability': actionability,
      'time_horizon': timeHorizon,
      'effort_level': effortLevel,
      'cost_level': costLevel,
      'difficulty': difficulty,
      'skill_level': skillLevel,
      'location': location,
      'time_required': timeRequired,
      'freshness_sensitivity': freshnessSensitivity,
      'evergreen_score': evergreenScore,
    };
  }

  static MemoryIntentMetadata? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final primaryIntent = TranscriptEnrichmentService._cleanText(
      json['primary_intent'] ?? json['primaryIntent'] ?? json['intent'],
    ).toLowerCase();
    final secondaryIntents = TranscriptEnrichmentService._extractStringList(
      json['secondary_intents'] ?? json['secondaryIntents'],
    ).map((item) => item.toLowerCase()).toList();
    final metadata = MemoryIntentMetadata(
      primaryIntent: primaryIntent,
      secondaryIntents: secondaryIntents,
      intentConfidence: _normalizedDouble(
        json['intent_confidence'] ?? json['intentConfidence'],
      ),
      lifeArea: TranscriptEnrichmentService._cleanNullableText(
        json['life_area'] ?? json['lifeArea'],
      ),
      whySavedHypothesis: TranscriptEnrichmentService._cleanNullableText(
        json['why_saved_hypothesis'] ??
            json['whySavedHypothesis'] ??
            json['why_saved'],
      ),
      actionability: TranscriptEnrichmentService._cleanNullableText(
        json['actionability'],
      ),
      timeHorizon: TranscriptEnrichmentService._cleanNullableText(
        json['time_horizon'] ?? json['timeHorizon'],
      ),
      effortLevel: TranscriptEnrichmentService._cleanNullableText(
        json['effort_level'] ?? json['effortLevel'],
      ),
      costLevel: TranscriptEnrichmentService._cleanNullableText(
        json['cost_level'] ?? json['costLevel'],
      ),
      difficulty: TranscriptEnrichmentService._cleanNullableText(
        json['difficulty'],
      ),
      skillLevel: TranscriptEnrichmentService._cleanNullableText(
        json['skill_level'] ?? json['skillLevel'],
      ),
      location: TranscriptEnrichmentService._cleanNullableText(
        json['location'],
      ),
      timeRequired: TranscriptEnrichmentService._cleanNullableText(
        json['time_required'] ?? json['timeRequired'],
      ),
      freshnessSensitivity: TranscriptEnrichmentService._cleanNullableText(
        json['freshness_sensitivity'] ?? json['freshnessSensitivity'],
      ),
      evergreenScore: _normalizedDouble(
        json['evergreen_score'] ?? json['evergreenScore'],
      ),
    );
    return metadata.hasUsefulContent ? metadata : null;
  }

  static double? _normalizedDouble(Object? raw) {
    if (raw == null) return null;
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw.toString().trim());
    if (value == null || value.isNaN) return null;
    return value.clamp(0, 1).toDouble();
  }
}

/// Nutrition information for a recipe (per serving).
class RecipeNutrition {
  const RecipeNutrition({
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.confidence,
    this.isEstimated = true,
    this.servings,
    this.source = RecipeNutritionSource.schema,
    this.unmatchedIngredients = const [],
    // Future dietary tags
    this.isVegetarian,
    this.isVegan,
    this.isGlutenFree,
    this.isDairyFree,
    this.isHighProtein,
  });

  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final double? confidence;
  final bool isEstimated;
  final int? servings;
  final RecipeNutritionSource source;
  final List<String> unmatchedIngredients;

  // Dietary tags (future-ready)
  final bool? isVegetarian;
  final bool? isVegan;
  final bool? isGlutenFree;
  final bool? isDairyFree;
  final bool? isHighProtein;

  bool get hasAnyValue =>
      calories != null ||
      proteinG != null ||
      carbsG != null ||
      fatG != null ||
      fiberG != null;

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'fiber_g': fiberG,
    'confidence': confidence,
    'is_estimated': isEstimated,
    'servings': servings,
    'source': source.name,
    if (unmatchedIngredients.isNotEmpty)
      'unmatched_ingredients': unmatchedIngredients,
    'is_vegetarian': isVegetarian,
    'is_vegan': isVegan,
    'is_gluten_free': isGlutenFree,
    'is_dairy_free': isDairyFree,
    'is_high_protein': isHighProtein,
  };

  static RecipeNutrition? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final n = RecipeNutrition(
      calories: _toDouble(json['calories'] ?? json['calorieContent']),
      proteinG: _toDouble(
        json['protein_g'] ?? json['protein'] ?? json['proteinContent'],
      ),
      carbsG: _toDouble(
        json['carbs_g'] ??
            json['carbs'] ??
            json['carbohydrates'] ??
            json['carbohydrateContent'],
      ),
      fatG: _toDouble(json['fat_g'] ?? json['fat'] ?? json['fatContent']),
      fiberG: _toDouble(
        json['fiber_g'] ?? json['fiber'] ?? json['fiberContent'],
      ),
      confidence: _toDouble(json['confidence']),
      isEstimated: json['is_estimated'] != false,
      servings: _toInt(json['servings'] ?? json['serving_count']),
      source: RecipeNutritionSource.fromJson(json['source']),
      unmatchedIngredients: TranscriptEnrichmentService._extractStringList(
        json['unmatched_ingredients'] ?? json['unmatchedIngredients'],
      ),
      isVegetarian: json['is_vegetarian'] as bool?,
      isVegan: json['is_vegan'] as bool?,
      isGlutenFree: json['is_gluten_free'] as bool?,
      isDairyFree: json['is_dairy_free'] as bool?,
      isHighProtein: json['is_high_protein'] as bool?,
    );
    return n.hasAnyValue ? n : null;
  }

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final text = v.toString().trim();
    final direct = double.tryParse(text);
    if (direct != null) return direct;
    final match = RegExp(r'-?\d+(?:[,.]\d+)?').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  static int? _toInt(Object? v) {
    final value = _toDouble(v);
    if (value == null || value <= 0) return null;
    return value.round();
  }
}

enum RecipeNutritionSource {
  schema,
  calculated;

  static RecipeNutritionSource fromJson(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'calculated' || 'database' || 'nutrition_database' => calculated,
      _ => schema,
    };
  }
}

class EnrichedRecipe {
  const EnrichedRecipe({
    required this.title,
    this.description,
    this.image,
    this.author,
    this.source,
    this.category,
    this.cuisine,
    this.servings,
    this.ingredients = const [],
    this.steps = const [],
    this.prepTime,
    this.cookTime,
    this.totalTime,
    this.summary,
    this.difficulty,
    this.tags = const [],
    this.nutrition,
    this.extractionSources = const [],
    this.nutritionAttempted = false,
  });

  final String title;
  final String? description;
  final String? image;
  final String? author;
  final String? source;
  final String? category;
  final String? cuisine;
  final String? servings;
  final List<EnrichedRecipeIngredient> ingredients;
  final List<String> steps;
  final String? prepTime;
  final String? cookTime;
  final String? totalTime;
  final String? summary;
  final String? difficulty;
  final List<String> tags;

  /// Estimated nutrition data (per serving). May be null if unavailable.
  final RecipeNutrition? nutrition;

  /// Source signals used during extraction (e.g. 'transcript', 'on_screen_text', 'caption').
  final List<String> extractionSources;

  /// True after one nutrition-generation pass, even if Gemini returned null.
  /// Prevents repeated re-enhancement when ingredients are insufficient for estimation.
  final bool nutritionAttempted;

  String? get instructions => steps.isEmpty ? null : steps.join('\n');

  bool get hasUsefulContent =>
      title.trim().isNotEmpty || ingredients.isNotEmpty || steps.isNotEmpty;

  EnrichedRecipe copyWith({
    String? title,
    String? description,
    String? image,
    String? author,
    String? source,
    String? category,
    String? cuisine,
    String? servings,
    List<EnrichedRecipeIngredient>? ingredients,
    List<String>? steps,
    String? prepTime,
    String? cookTime,
    String? totalTime,
    String? summary,
    String? difficulty,
    List<String>? tags,
    RecipeNutrition? nutrition,
    List<String>? extractionSources,
    bool? nutritionAttempted,
  }) {
    return EnrichedRecipe(
      title: title ?? this.title,
      description: description ?? this.description,
      image: image ?? this.image,
      author: author ?? this.author,
      source: source ?? this.source,
      category: category ?? this.category,
      cuisine: cuisine ?? this.cuisine,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      totalTime: totalTime ?? this.totalTime,
      summary: summary ?? this.summary,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      nutrition: nutrition ?? this.nutrition,
      extractionSources: extractionSources ?? this.extractionSources,
      nutritionAttempted: nutritionAttempted ?? this.nutritionAttempted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'image': image,
      'author': author,
      'source': source,
      'category': category,
      'cuisine': cuisine,
      'servings': servings,
      'ingredients': ingredients.map((item) => item.toJson()).toList(),
      'steps': steps,
      'instructions': instructions,
      'prep_time': prepTime,
      'cook_time': cookTime,
      'total_time': totalTime,
      'summary': summary,
      'difficulty': difficulty,
      'tags': tags,
      if (nutrition != null) 'nutrition': nutrition!.toJson(),
      if (extractionSources.isNotEmpty) 'extraction_sources': extractionSources,
      if (nutritionAttempted) 'nutrition_attempted': true,
    };
  }

  static EnrichedRecipe? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final ingredients = _parseIngredients(json['ingredients']);
    final steps = _parseSteps(json['steps'] ?? json['instructions']);
    final recipe = EnrichedRecipe(
      title: TranscriptEnrichmentService._cleanText(
        json['title'] ?? json['name'],
      ),
      description: TranscriptEnrichmentService._cleanNullableText(
        json['description'],
      ),
      image: TranscriptEnrichmentService._cleanNullableText(
        json['image'] ?? json['thumbnail'] ?? json['thumbnail_url'],
      ),
      author: TranscriptEnrichmentService._cleanNullableText(json['author']),
      source: TranscriptEnrichmentService._cleanNullableText(
        json['source'] ?? json['publisher'],
      ),
      category: TranscriptEnrichmentService._cleanNullableText(
        json['category'],
      ),
      cuisine: TranscriptEnrichmentService._cleanNullableText(
        json['cuisine'] ?? json['area'],
      ),
      servings: TranscriptEnrichmentService._cleanNullableText(
        json['servings'] ?? json['yield'] ?? json['recipe_yield'],
      ),
      ingredients: ingredients,
      steps: steps,
      prepTime: TranscriptEnrichmentService._cleanNullableText(
        json['prep_time'] ?? json['prepTime'],
      ),
      cookTime: TranscriptEnrichmentService._cleanNullableText(
        json['cook_time'] ?? json['cookTime'],
      ),
      totalTime: TranscriptEnrichmentService._cleanNullableText(
        json['total_time'] ?? json['totalTime'],
      ),
      summary: TranscriptEnrichmentService._cleanNullableText(
        json['summary'] ?? json['recipe_summary'],
      ),
      difficulty: TranscriptEnrichmentService._cleanNullableText(
        json['difficulty'],
      ),
      tags: TagNoiseFilter.filterTags(
        TranscriptEnrichmentService._extractStringList(json['tags']),
      ),
      nutrition: RecipeNutrition.fromJsonOrNull(
        json['nutrition'] ??
            json['nutrition_per_serving'] ??
            json['nutritionPerServing'] ??
            json,
      ),
      extractionSources: TranscriptEnrichmentService._extractStringList(
        json['extraction_sources'],
      ),
      nutritionAttempted: json['nutrition_attempted'] == true,
    );
    return recipe.hasUsefulContent ? recipe : null;
  }

  static List<String> _parseSteps(Object? raw) {
    if (raw is String) {
      return _splitInstructionString(raw);
    }
    if (raw is! List) return const [];
    final out = <String>[];
    for (final item in raw) {
      if (item is String) {
        // A single-element list containing a wall of text — split it.
        final candidates = _splitInstructionString(item);
        out.addAll(candidates);
      } else if (item is Map) {
        final json = Map<String, dynamic>.from(item);
        final nested = json['itemListElement'] ?? json['steps'];
        if (nested is List) {
          out.addAll(_parseSteps(nested));
          continue;
        }
        final text = TranscriptEnrichmentService._cleanText(
          json['text'] ?? json['description'] ?? json['name'],
        );
        // If this single map-step looks like a transcript dump, try splitting.
        if (text.isNotEmpty) {
          final candidates = text.length > 250
              ? _splitInstructionString(text)
              : [text];
          out.addAll(candidates);
        }
      }
    }
    return out.take(40).toList();
  }

  /// Splits a raw instruction string into individual step strings.
  ///
  /// Handles:
  /// - Explicit numbered steps ("1. Do this. 2. Do that." or "Step 1: ...")
  /// - Newline-delimited steps
  /// - Sentence-boundary splitting for single-block transcripts
  static List<String> _splitInstructionString(String raw) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return const [];

    // 1. Try numbered-step markers ("1.", "1)", "Step 1:", "Step 1 -").
    final numberedSplit = normalized
        .split(
          RegExp(
            r'(?:^|\n)\s*(?:step\s*)?\d+[.):\-]\s+',
            caseSensitive: false,
            multiLine: true,
          ),
        )
        .map(TranscriptEnrichmentService._cleanText)
        .where((item) => item.isNotEmpty)
        .toList();
    if (numberedSplit.length >= 3) return numberedSplit;

    // 2. Try newline splitting.
    final newlineSplit = normalized
        .split(RegExp(r'\n+'))
        .map(TranscriptEnrichmentService._cleanText)
        .where((item) => item.isNotEmpty)
        .toList();
    if (newlineSplit.length >= 3) return newlineSplit;

    // 3. If the whole thing is one or two lines (e.g. a transcript blob),
    //    split on sentence boundaries that look like new cooking actions.
    //    We look for ". " followed by a capital letter or a common transition
    //    word (Then, Next, Add, Cook, Stir, etc.).
    final sentenceSplit = normalized
        .split(
          RegExp(
            r'\.\s+(?=[A-Z]|Then |Next |Add |Cook |Stir |Combine |Mix |Fold |Pour |Place |Remove |Transfer |Season |Garnish |Serve |Top |Drain |Rinse |Bring |Reduce |Let |Allow |Set |Heat |Melt |Sauté|Saute |Fry |Boil |Bake |Roast |Grill |Simmer |Whisk |Toss |Coat |Taste |Adjust )',
          ),
        )
        .map((s) {
          final cleaned = TranscriptEnrichmentService._cleanText(s);
          // Re-append the period that was consumed by the split.
          return cleaned.endsWith('.') ? cleaned : '$cleaned.';
        })
        .where((item) => item.length > 10)
        .toList();
    if (sentenceSplit.length >= 3) return sentenceSplit;

    // 4. Nothing worked — return as a single step (AI will fix it during enhance).
    return [normalized];
  }

  static List<EnrichedRecipeIngredient> _parseIngredients(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is String) {
            return EnrichedRecipeIngredient(
              name: TranscriptEnrichmentService._cleanText(item),
            );
          }
          if (item is Map) {
            final json = Map<String, dynamic>.from(item);
            return EnrichedRecipeIngredient(
              name: TranscriptEnrichmentService._cleanText(
                json['name'] ?? json['ingredient'] ?? json['title'],
              ),
              quantity: TranscriptEnrichmentService._cleanNullableText(
                json['quantity'] ?? json['amount'],
              ),
              unit: TranscriptEnrichmentService._cleanNullableText(
                json['unit'],
              ),
              notes: TranscriptEnrichmentService._cleanNullableText(
                json['notes'] ?? json['note'],
              ),
              legacyMeasure: TranscriptEnrichmentService._cleanNullableText(
                json['measure'] ?? json['measurement'],
              ),
            );
          }
          return null;
        })
        .whereType<EnrichedRecipeIngredient>()
        .where((item) => item.name.isNotEmpty)
        .take(30)
        .toList();
  }
}

class EnrichedRecipeIngredient {
  const EnrichedRecipeIngredient({
    required this.name,
    this.quantity,
    this.unit,
    this.notes,
    this.legacyMeasure,
  });

  final String name;
  final String? quantity;
  final String? unit;
  final String? notes;
  final String? legacyMeasure;

  String get amountLabel {
    final structured = [quantity, unit]
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join(' ');
    if (structured.isNotEmpty) return structured;
    return legacyMeasure?.trim() ?? '';
  }

  String get displayText {
    final parts = <String>[
      if (amountLabel.isNotEmpty) amountLabel,
      name,
      if ((notes ?? '').trim().isNotEmpty) notes!.trim(),
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
      if ((legacyMeasure ?? '').isNotEmpty) 'measure': legacyMeasure,
    };
  }
}

class EnrichedContentStep {
  const EnrichedContentStep({required this.title, this.description});

  final String title;
  final String? description;

  Map<String, dynamic> toJson() {
    return {'title': title, 'description': description};
  }

  bool get hasUsefulContent =>
      title.trim().isNotEmpty || (description?.trim().isNotEmpty ?? false);
}

class EnrichedContentSection {
  const EnrichedContentSection({required this.title, required this.points});

  final String title;
  final List<String> points;

  bool get hasUsefulContent => title.trim().isNotEmpty && points.isNotEmpty;

  Map<String, dynamic> toJson() => {'title': title, 'points': points};

  static EnrichedContentSection? fromJson(Map<String, dynamic> json) {
    final title = TranscriptEnrichmentService._cleanText(
      json['title'] ?? json['heading'] ?? json['name'],
    );
    final points = TranscriptEnrichmentService._extractStringList(
      json['points'] ?? json['items'] ?? json['details'],
    );
    if (title.isEmpty || points.isEmpty) return null;
    return EnrichedContentSection(
      title: title,
      points: points.take(6).toList(),
    );
  }
}

class EnrichedMention {
  const EnrichedMention({
    required this.title,
    required this.type,
    this.year,
    this.whyMentioned,
    this.posterUrl,
  });

  final String title;
  final String type;
  final String? year;
  final String? whyMentioned;
  final String? posterUrl;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      'year': year,
      'why_mentioned': whyMentioned,
      'poster_url': posterUrl,
    };
  }

  static EnrichedMention fromJson(Map<String, dynamic> json) {
    return EnrichedMention(
      title: TranscriptEnrichmentService._cleanText(
        json['title'] ?? json['name'],
      ),
      type: TranscriptEnrichmentService._normalizeMentionType(json['type']),
      year: TranscriptEnrichmentService._cleanNullableText(json['year']),
      whyMentioned: TranscriptEnrichmentService._cleanNullableText(
        json['why_mentioned'],
      ),
      posterUrl: TranscriptEnrichmentService._cleanNullableText(
        json['poster_url'],
      ),
    );
  }
}

class EnrichedNotableItem {
  const EnrichedNotableItem({
    required this.text,
    required this.type,
    this.label,
    this.attribution,
    this.whyImportant,
  });

  final String text;
  final String type;
  final String? label;
  final String? attribution;
  final String? whyImportant;

  bool get hasUsefulContent => text.trim().isNotEmpty;

  bool get isMusicItem {
    final descriptor = '${type.trim()} ${label?.trim() ?? ''}'.toLowerCase();
    return RegExp(
      r'\b(song|track|album|music|artist|band)\b',
    ).hasMatch(descriptor);
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type,
      'label': label,
      'attribution': attribution,
      'why_important': whyImportant,
    };
  }

  static EnrichedNotableItem fromJson(Map<String, dynamic> json) {
    return EnrichedNotableItem(
      text: TranscriptEnrichmentService._cleanText(
        json['text'] ?? json['quote'] ?? json['name'] ?? json['title'],
      ),
      type: TranscriptEnrichmentService._cleanText(json['type']).isEmpty
          ? 'reference'
          : TranscriptEnrichmentService._cleanText(json['type']).toLowerCase(),
      label: TranscriptEnrichmentService._cleanNullableText(
        json['label'] ?? json['title'] ?? json['name'],
      ),
      attribution: TranscriptEnrichmentService._cleanNullableText(
        json['attribution'] ?? json['speaker'] ?? json['source'],
      ),
      whyImportant: TranscriptEnrichmentService._cleanNullableText(
        json['why_important'] ?? json['whyImportant'] ?? json['why'],
      ),
    );
  }
}

class TranscriptEnrichmentService {
  TranscriptEnrichmentService({AiTransport? transport})
    : _transport = transport ?? AiTransport.instance;

  final AiTransport _transport;
  static final Map<String, TranscriptEnrichmentResult> _memoryCache = {};
  static const _cachePrefix = 'transcript_enrichment_v5_';

  static bool supportsUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final normalizedHost = host.startsWith('www.') ? host.substring(4) : host;
    // Must stay in lockstep with the Worker's isInstagramReelUrl
    // (services/shared.ts). Any media URL the Worker will send to Apify must
    // also be treated as "supported" here, otherwise the client routes it to
    // the generic Gemini fallback and saves caption-only metadata as READY.
    if ((normalizedHost == 'instagram.com' ||
            normalizedHost.endsWith('.instagram.com') ||
            normalizedHost == 'instagr.am') &&
        RegExp(r'/(reel|reels|p|tv|share)/').hasMatch(uri.path)) {
      return true;
    }
    if (normalizedHost == 'tiktok.com' ||
        normalizedHost.endsWith('.tiktok.com')) {
      return RegExp(r'/@[^/]+/video/\d+').hasMatch(uri.path);
    }
    if (normalizedHost == 'youtu.be') return uri.pathSegments.isNotEmpty;
    if (normalizedHost == 'youtube.com' ||
        normalizedHost.endsWith('.youtube.com') ||
        normalizedHost == 'youtube-nocookie.com' ||
        normalizedHost.endsWith('.youtube-nocookie.com')) {
      return uri.queryParameters['v']?.isNotEmpty == true ||
          RegExp(r'^/(shorts|embed)/[^/]+').hasMatch(uri.path);
    }
    return false;
  }

  /// Reads only local transcript enrichment cache. This never calls the backend.
  static Future<TranscriptEnrichmentResult?> cachedResultForUrl(
    String rawUrl,
  ) async {
    final cacheKey = _cacheKeyForUrl(rawUrl);
    final cached = _memoryCache[cacheKey];
    if (_isAcceptableCachedResult(rawUrl, cached)) return cached;
    if (cached != null) _memoryCache.remove(cacheKey);
    final persisted = await _readPersisted(cacheKey);
    if (persisted != null) {
      if (_isAcceptableCachedResult(rawUrl, persisted)) {
        _memoryCache[cacheKey] = persisted;
        return persisted;
      }
      await _removePersisted(cacheKey);
    }
    return null;
  }

  Future<TranscriptEnrichmentResult?> enrichUrl({
    required String rawUrl,
    required String title,
    required String description,
    required String? thumbnailUrl,
    required String domain,
    String? saveId,
    String? processingId,
    int attempt = 1,
    bool forceRefresh = false,
  }) async {
    if (!supportsUrl(rawUrl)) return null;
    final cacheKey = _cacheKeyForUrl(rawUrl);
    if (forceRefresh) {
      _memoryCache.remove(cacheKey);
      await _removePersisted(cacheKey);
    }
    final cached = _memoryCache[cacheKey];
    if (!forceRefresh && _isAcceptableCachedResult(rawUrl, cached)) {
      return cached;
    }
    if (cached != null) _memoryCache.remove(cacheKey);
    final persisted = await _readPersisted(cacheKey);
    if (!forceRefresh && persisted != null) {
      if (_isAcceptableCachedResult(rawUrl, persisted)) {
        _memoryCache[cacheKey] = persisted;
        return persisted;
      }
      await _removePersisted(cacheKey);
    }

    try {
      final requestData = <String, dynamic>{
        'url': rawUrl,
        'attempt': attempt,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'domain': domain,
      };
      if (saveId != null) requestData['save_id'] = saveId;
      if (processingId != null) requestData['processing_id'] = processingId;
      final data = await _transport.postEnrichment(body: requestData);

      final mentions = _extractMentions(data);
      final recipe = EnrichedRecipe.fromJsonOrNull(data['recipe']);
      final mentionTitles = mentions
          .map((item) => TagNoiseFilter.cleanTag(item.title))
          .where((item) => item.isNotEmpty)
          .toSet();
      final tags = TagNoiseFilter.filterTags(_extractTags(data))
          .where((tag) => !mentionTitles.contains(TagNoiseFilter.cleanTag(tag)))
          .toList();
      final usefulTags = _ensureUsefulTags(
        tags,
        data,
        hasMovieMentions: mentions.any((item) => item.type == 'movie'),
        hasRecipe: recipe != null,
      ).take(8).toList();

      final result = TranscriptEnrichmentResult(
        schemaVersion:
            _extractPositiveInt(
              data['schema_version'] ?? data['schemaVersion'],
            ) ??
            1,
        meaningfulTitle: _cleanText(data['meaningful_title']),
        summary: _cleanText(data['summary']),
        category: _cleanText(data['category']),
        tags: usefulTags,
        contentType: recipe != null ? 'recipe' : _contentTypeFromJson(data),
        brief: _cleanNullableText(
          data['brief'] ??
              data['short_description'] ??
              data['content_description'],
        ),
        steps: _extractContentSteps(data),
        mentions: mentions,
        recipe: recipe,
        keyPoints: _extractStringList(data['key_points']),
        notableItems: _extractNotableItems(data),
        contentSections: _extractContentSections(data),
        categoryEvidence: _cleanNullableText(
          data['category_evidence'] ?? data['domain_evidence'],
        ),
        categoryConfidence: _toDouble(
          data['category_confidence'] ??
              data['domain_confidence'] ??
              data['confidence'],
        ),
        topics: _extractStringList(data['topics']),
        categoryNeedsReview:
            data['category_needs_review'] == true ||
            data['domain_needs_review'] == true,
        originalGeminiCategory: _cleanNullableText(
          data['original_gemini_category'] ?? data['original_gemini_domain'],
        ),
        thumbnailUrl: _cleanText(data['thumbnail_url']).isNotEmpty
            ? _cleanText(data['thumbnail_url'])
            : null,
        creator: _cleanText(data['creator']).isNotEmpty
            ? _cleanText(data['creator'])
            : null,
        caption: _cleanText(data['caption']).isNotEmpty
            ? _cleanText(data['caption'])
            : null,
        transcript: _cleanText(data['transcript']).isNotEmpty
            ? _cleanText(data['transcript'])
            : null,
        ocrText: _cleanText(data['ocr_text'] ?? data['ocrText']).isNotEmpty
            ? _cleanText(data['ocr_text'] ?? data['ocrText'])
            : null,
        likeCount: _extractPositiveInt(data['like_count']),
        commentCount: _extractPositiveInt(data['comment_count']),
        imageUrls: _extractStringList(
          data['image_urls'] ?? data['imageUrls'] ?? data['images'],
        ),
        firstComment:
            _cleanText(data['first_comment'] ?? data['firstComment']).isNotEmpty
            ? _cleanText(data['first_comment'] ?? data['firstComment'])
            : null,
        latestComments: _extractStringList(
          data['latest_comments'] ?? data['latestComments'],
        ),
        memoryIntent: MemoryIntentMetadata.fromJsonOrNull(
          data['memory_intent'] ?? data,
        ),
      );

      if (!result.hasUsefulContent ||
          (supportsUrl(rawUrl) &&
              (!result.hasReliableMediaEvidence ||
                  !result.hasStructuredEnrichment))) {
        throw const TranscriptEnrichmentException(
          'backend_returned_low_quality_evidence',
        );
      }
      _memoryCache[cacheKey] = result;
      await _writePersisted(cacheKey, result);
      return result;
    } on TranscriptEnrichmentException {
      rethrow;
    } on AiTransportException catch (error) {
      throw TranscriptEnrichmentException(
        'backend_http_${error.statusCode ?? 0}',
        statusCode: error.statusCode,
        retryable: error.isRetryable,
      );
    } catch (e, st) {
      developer.log(
        'Transcript enrichment failed: ${e.runtimeType}',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
      throw TranscriptEnrichmentException(e.toString());
    }
  }

  static bool _isAcceptableCachedResult(
    String rawUrl,
    TranscriptEnrichmentResult? result,
  ) {
    if (result == null || !result.hasUsefulContent) return false;
    if (supportsUrl(rawUrl) &&
        (!result.hasReliableMediaEvidence || !result.hasStructuredEnrichment)) {
      return false;
    }
    return true;
  }

  static List<EnrichedContentStep> _extractContentSteps(
    Map<String, dynamic> data,
  ) {
    final raw = data['steps'] ?? data['key_steps'] ?? data['takeaways'];
    final parsed = _parseContentSteps(raw);
    if (parsed.isNotEmpty) return parsed;

    final keyPoints = data['key_points'];
    return _parseContentSteps(keyPoints);
  }

  static List<EnrichedNotableItem> _extractNotableItems(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['notable_items'] ??
        data['notableItems'] ??
        data['highlight_items'] ??
        data['highlights'];
    if (raw is! List) return const [];
    final seen = <String>{};
    return raw
        .map((item) {
          if (item is String) {
            final text = _cleanText(item);
            if (text.isEmpty) return null;
            return EnrichedNotableItem(text: text, type: 'quote');
          }
          if (item is Map) {
            return EnrichedNotableItem.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return null;
        })
        .whereType<EnrichedNotableItem>()
        .where((item) => item.hasUsefulContent)
        .where((item) {
          final key = _cleanText(item.text).toLowerCase();
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        })
        .take(12)
        .toList();
  }

  static List<EnrichedContentSection> _extractContentSections(
    Map<String, dynamic> data,
  ) {
    final raw = data['content_sections'] ?? data['contentSections'];
    if (raw is! List) return const [];
    final seenTitles = <String>{};
    final seenPoints = <String>{};
    var totalPoints = 0;
    final sections = <EnrichedContentSection>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final parsed = EnrichedContentSection.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (parsed == null) continue;
      final titleKey = _cleanText(parsed.title).toLowerCase();
      if (!seenTitles.add(titleKey)) continue;
      final points = <String>[];
      for (final point in parsed.points) {
        final key = _cleanText(point).toLowerCase();
        if (key.isEmpty || !seenPoints.add(key)) continue;
        points.add(point);
        totalPoints++;
        if (points.length >= 6 || totalPoints >= 32) break;
      }
      if (points.isNotEmpty) {
        sections.add(
          EnrichedContentSection(title: parsed.title, points: points),
        );
      }
      if (sections.length >= 8 || totalPoints >= 32) break;
    }
    return sections;
  }

  static List<EnrichedContentStep> _parseContentSteps(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is String) {
            final text = _cleanText(item);
            if (text.isEmpty) return null;
            final split = _splitStepTitle(text);
            return EnrichedContentStep(title: split.$1, description: split.$2);
          }
          if (item is Map) {
            final json = Map<String, dynamic>.from(item);
            final title = _cleanText(
              json['title'] ??
                  json['label'] ??
                  json['step'] ??
                  json['name'] ??
                  json['point'],
            );
            final description = _cleanNullableText(
              json['description'] ??
                  json['summary'] ??
                  json['detail'] ??
                  json['why'],
            );
            if (title.isEmpty && (description ?? '').isEmpty) return null;
            if (title.isEmpty) {
              final split = _splitStepTitle(description!);
              return EnrichedContentStep(
                title: split.$1,
                description: split.$2,
              );
            }
            return EnrichedContentStep(title: title, description: description);
          }
          return null;
        })
        .whereType<EnrichedContentStep>()
        .where((item) => item.hasUsefulContent)
        .take(12)
        .toList();
  }

  static (String, String?) _splitStepTitle(String text) {
    final cleaned = _cleanText(text);
    final index = cleaned.indexOf(':');
    if (index > 2 && index <= 48) {
      final title = cleaned.substring(0, index).trim();
      final description = cleaned.substring(index + 1).trim();
      return (title, description.isEmpty ? null : description);
    }
    return (cleaned, null);
  }

  static List<String> _extractTags(Map<String, dynamic> data) {
    final raw = data['tags'];
    if (raw is! List) return const [];
    return raw
        .map((item) => _cleanText(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<EnrichedMention> _extractMentions(Map<String, dynamic> data) {
    final byKey = <String, EnrichedMention>{};
    final mentions = data['mentions'];
    if (mentions is List) {
      for (final item in mentions) {
        if (item is! Map) continue;
        final mention = EnrichedMention.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (mention.title.isEmpty) continue;
        byKey[_mentionKey(mention.title)] = mention;
      }
    }
    final books = data['books'];
    if (books is List) {
      for (final item in books) {
        if (item is! Map) continue;
        final title = _cleanText(item['title']);
        if (title.isEmpty) continue;
        byKey[_mentionKey(title)] = EnrichedMention(
          title: title,
          type: 'book',
          whyMentioned: _cleanNullableText(
            item['why_mentioned'] ?? item['reason'] ?? item['description'],
          ),
          posterUrl: _cleanNullableText(item['cover_url'] ?? item['coverUrl']),
        );
      }
    }
    final movies = data['movies'];
    if (movies is List) {
      for (final item in movies) {
        if (item is! Map) continue;
        final title = _cleanText(item['title']);
        if (title.isEmpty) continue;
        byKey[_mentionKey(title)] = EnrichedMention(
          title: title,
          type: 'movie',
          year: _cleanNullableText(item['year']),
          whyMentioned: _cleanNullableText(
            item['why_mentioned'] ?? item['reason'] ?? item['description'],
          ),
          posterUrl: _cleanNullableText(
            item['poster_url'] ?? item['posterUrl'],
          ),
        );
      }
    }
    final places = data['places'];
    if (places is List) {
      for (final item in places) {
        if (item is! Map) continue;
        final title = _cleanText(item['name'] ?? item['title']);
        if (title.isEmpty) continue;
        final locale = [
          _cleanText(item['city']),
          _cleanText(item['country']),
        ].where((part) => part.isNotEmpty).join(', ');
        byKey.putIfAbsent(
          _mentionKey(title),
          () => EnrichedMention(
            title: title,
            type: 'place',
            whyMentioned:
                _cleanNullableText(
                  item['why_mentioned'] ??
                      item['reason'] ??
                      item['description'],
                ) ??
                (locale.isEmpty ? null : locale),
          ),
        );
      }
    }
    final entities = data['entities'];
    if (entities is List) {
      for (final item in entities) {
        if (item is! Map) continue;
        final type = _normalizeMentionType(item['type']);
        final title = _cleanText(item['name'] ?? item['title']);
        if (title.isEmpty) continue;
        final key = _mentionKey(title);
        byKey.putIfAbsent(
          key,
          () => EnrichedMention(
            title: title,
            type: type,
            whyMentioned: _cleanNullableText(
              item['why_mentioned'] ?? item['reason'],
            ),
          ),
        );
      }
    }
    return byKey.values.take(20).toList();
  }

  static String _normalizeMentionType(Object? raw) {
    final type = _cleanText(raw).toLowerCase().replaceAll('-', '_');
    return switch (type) {
      'movie' ||
      'film' ||
      'show' ||
      'series' ||
      'anime' ||
      'documentary' => 'movie',
      'book' || 'novel' => 'book',
      'place' || 'location' || 'destination' => 'place',
      'product' => 'product',
      'app' || 'application' => 'app',
      'person' || 'creator' || 'author' => 'person',
      'game' || 'video_game' || 'mobile_game' => 'game',
      'music' ||
      'song' ||
      'track' ||
      'album' ||
      'artist' ||
      'band' ||
      'musician' => 'music',
      'tool' ||
      'website' ||
      'service' ||
      'platform' ||
      'software' ||
      'repository' => 'tool',
      _ => 'other',
    };
  }

  static List<String> _extractStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => _cleanText(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _contentTypeFromJson(Map<String, dynamic> json) {
    final explicit = _cleanText(
      json['content_type'] ?? json['contentType'],
    ).toLowerCase();
    if (explicit.isNotEmpty) return explicit;
    return EnrichedRecipe.fromJsonOrNull(json['recipe']) != null
        ? 'recipe'
        : 'generic';
  }

  static List<String> _ensureUsefulTags(
    List<String> tags,
    Map<String, dynamic> data, {
    required bool hasMovieMentions,
    required bool hasRecipe,
  }) {
    final out = <String>[...tags];
    final haystack = [
      data['meaningful_title'],
      data['summary'],
      data['category'],
      data['transcript'],
      data['caption'],
    ].map(_cleanText).join(' ').toLowerCase();
    void add(String tag) {
      final clean = TagNoiseFilter.cleanTag(tag);
      if (clean.isNotEmpty &&
          !TagNoiseFilter.isNoiseTag(clean) &&
          !out.contains(clean)) {
        out.add(clean);
      }
    }

    if (hasMovieRecommendationIntentForEnrichment(
      data,
      hasMovieMentions: hasMovieMentions,
    )) {
      add('movie recommendations');
      if (haystack.contains('sci-fi') || haystack.contains('science fiction')) {
        add('sci-fi movies');
      }
      if (haystack.contains('mind-bending') ||
          haystack.contains('time travel')) {
        add('mind-bending films');
      }
    }
    if (hasRecipe || haystack.contains('recipe') || haystack.contains('cook')) {
      add('recipe');
      if (haystack.contains('protein')) add('protein recipes');
      if (haystack.contains('vegan')) add('vegan recipes');
      if (haystack.contains('meal prep')) add('meal prep');
    }
    return TagNoiseFilter.filterTags(out);
  }

  static String _cleanText(Object? raw) {
    return TextCleaner.cleanLoose(raw);
  }

  static String? _cleanNullableText(Object? raw) {
    final text = _cleanText(raw);
    return text.isEmpty ? null : text;
  }

  static double? _toDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    final value = double.tryParse(_cleanText(raw));
    return value;
  }

  static int? _extractPositiveInt(Object? raw) {
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw > 0) return raw.round();
    final text = _cleanText(raw).replaceAll(',', '');
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return value.round();
  }

  static String _cacheKeyForUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return rawUrl.trim();
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);

    if (host == 'youtu.be') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (id.isNotEmpty) return 'https://www.youtube.com/watch?v=$id';
    }
    if (host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com')) {
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      String? id;
      if (segments.isNotEmpty &&
          segments.first == 'shorts' &&
          segments.length >= 2) {
        id = segments[1];
      } else if (segments.isNotEmpty &&
          segments.first == 'embed' &&
          segments.length >= 2) {
        id = segments[1];
      } else {
        id = uri.queryParameters['v'];
      }
      if (id != null && id.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$id';
      }
    }
    if (host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'instagr.am') {
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      if (segments.length >= 2 &&
          {'reel', 'reels', 'p', 'tv'}.contains(segments.first.toLowerCase())) {
        return 'https://www.instagram.com/${segments.first}/${segments[1]}/';
      }
    }
    if (host == 'tiktok.com' || host.endsWith('.tiktok.com')) {
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      final videoIndex = segments.indexWhere(
        (item) => item.toLowerCase() == 'video',
      );
      if (videoIndex > 0 && videoIndex + 1 < segments.length) {
        return 'https://www.tiktok.com/${segments[videoIndex - 1]}/video/${segments[videoIndex + 1]}';
      }
    }
    return uri.replace(fragment: '', query: '').toString();
  }

  static String _mentionKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static Future<TranscriptEnrichmentResult?> _readPersisted(
    String rawUrl,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$rawUrl');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final result = TranscriptEnrichmentResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return result?.hasUsefulContent == true ? result : null;
    } catch (e, st) {
      developer.log(
        'Transcript enrichment cache read failed: $e',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
      return null;
    }
  }

  static Future<void> _writePersisted(
    String rawUrl,
    TranscriptEnrichmentResult result,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cachePrefix$rawUrl',
        jsonEncode(result.toJson()),
      );
    } catch (e, st) {
      developer.log(
        'Transcript enrichment cache write failed: $e',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
    }
  }

  static Future<void> _removePersisted(String rawUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$rawUrl');
    } catch (e, st) {
      developer.log(
        'Transcript enrichment cache remove failed: $e',
        name: 'TranscriptEnrichment',
        stackTrace: st,
      );
    }
  }
}
