part of 'transcript_enrichment_service.dart';

class TranscriptEnrichmentResult {
  const TranscriptEnrichmentResult({
    this.schemaVersion = 1,
    this.outputLocale = 'en',
    required this.meaningfulTitle,
    required this.summary,
    required this.category,
    required this.tags,
    this.contentType = 'generic',
    this.brief,
    this.notificationBlurb,
    this.evidenceBasis,
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
  final String outputLocale;
  final String meaningfulTitle;
  final String summary;
  final String category;
  final List<String> tags;
  final String contentType;
  final String? brief;
  final String? notificationBlurb;
  final String? evidenceBasis;

  bool get hasPartialMediaEvidence => const {
    'on_screen',
    'caption_only',
    'metadata_only',
  }.contains(evidenceBasis);
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
    // Explicitly limited media previews need not manufacture extra sections
    // or takeaways just to satisfy the full-reader quality gate.
    if (hasPartialMediaEvidence &&
        hasReliableMediaEvidence &&
        summary.trim().isNotEmpty) {
      return true;
    }
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
    String? outputLocale,
    String? meaningfulTitle,
    String? summary,
    String? category,
    List<String>? tags,
    String? contentType,
    String? brief,
    String? notificationBlurb,
    String? evidenceBasis,
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
      outputLocale: outputLocale ?? this.outputLocale,
      meaningfulTitle: meaningfulTitle ?? this.meaningfulTitle,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      contentType: contentType ?? this.contentType,
      brief: brief ?? this.brief,
      notificationBlurb: notificationBlurb ?? this.notificationBlurb,
      evidenceBasis: evidenceBasis ?? this.evidenceBasis,
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
      'output_locale': outputLocale,
      'meaningful_title': meaningfulTitle,
      'summary': summary,
      'category': category,
      'tags': tags,
      'content_type': contentType,
      'brief': brief,
      'notification_blurb': notificationBlurb,
      if (evidenceBasis != null) 'evidence_basis': evidenceBasis,
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
    final mentions = TranscriptEnrichmentService._extractMentions(json);
    return TranscriptEnrichmentResult(
      schemaVersion:
          TranscriptEnrichmentService._extractPositiveInt(
            json['schema_version'] ?? json['schemaVersion'],
          ) ??
          1,
      outputLocale: TranscriptEnrichmentService._cleanText(
        json['output_locale'] ?? json['outputLocale'] ?? 'en',
      ),
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
      evidenceBasis: TranscriptEnrichmentService._cleanNullableText(
        json['evidence_basis'],
      ),
      notificationBlurb: TranscriptEnrichmentService._cleanNullableText(
        json['notification_blurb'] ?? json['notificationBlurb'],
      ),
      steps: TranscriptEnrichmentService._extractContentSteps(json),
      mentions: mentions,
      notableItems: TranscriptEnrichmentService._extractNotableItems(
        json,
        excludingTitles: mentions
            .where((item) => item.type != 'other')
            .map((item) => item.title),
      ),
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
    if (RegExp(r'[\u3040-\u30ff\u3400-\u9fff]').hasMatch(text)) {
      return true;
    }
    final words = RegExp(r'''[^\s.,!?;:'"()\[\]{}…、。！？]+''', unicode: true)
        .allMatches(text)
        .map((match) => match.group(0) ?? '')
        .where((word) => word.length >= 2)
        .length;
    return words >= minWords;
  }

  static bool _sameLooseText(String a, String b) {
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'''[\s.,!?;:'"()\[\]{}…、。！？・]+'''), ' ')
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
    this.subtype,
    this.creator,
    this.year,
    this.whyMentioned,
    this.posterUrl,
    this.genres = const [],
    this.rawGenres = const [],
    this.catalogId,
    this.catalogSource,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.matchConfidence,
    this.libraryStatus,
    this.pageCount,
    this.currentPage,
    this.plot,
    this.imdbRating,
  });

  final String title;
  final String type;
  final String? subtype;
  final String? creator;
  final String? year;
  final String? whyMentioned;
  final String? posterUrl;
  final List<String> genres;
  final List<String> rawGenres;
  final String? catalogId;
  final String? catalogSource;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final double? matchConfidence;
  final String? libraryStatus;
  final int? pageCount;
  final int? currentPage;
  final String? plot;
  final double? imdbRating;

  String? get artworkUrl => posterUrl;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  EnrichedMention copyWith({
    String? title,
    String? type,
    String? subtype,
    String? creator,
    String? year,
    String? whyMentioned,
    String? posterUrl,
    List<String>? genres,
    List<String>? rawGenres,
    String? catalogId,
    String? catalogSource,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    double? matchConfidence,
    String? libraryStatus,
    int? pageCount,
    int? currentPage,
    String? plot,
    double? imdbRating,
  }) {
    return EnrichedMention(
      title: title ?? this.title,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      creator: creator ?? this.creator,
      year: year ?? this.year,
      whyMentioned: whyMentioned ?? this.whyMentioned,
      posterUrl: posterUrl ?? this.posterUrl,
      genres: genres ?? this.genres,
      rawGenres: rawGenres ?? this.rawGenres,
      catalogId: catalogId ?? this.catalogId,
      catalogSource: catalogSource ?? this.catalogSource,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      libraryStatus: libraryStatus ?? this.libraryStatus,
      pageCount: pageCount ?? this.pageCount,
      currentPage: currentPage ?? this.currentPage,
      plot: plot ?? this.plot,
      imdbRating: imdbRating ?? this.imdbRating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      'subtype': subtype,
      'creator': creator,
      'year': year,
      'why_mentioned': whyMentioned,
      'poster_url': posterUrl,
      'genres': genres,
      'raw_genres': rawGenres,
      'catalog_id': catalogId,
      'catalog_source': catalogSource,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'match_confidence': matchConfidence,
      'user_library_status': libraryStatus,
      'page_count': pageCount,
      'current_page': currentPage,
      'plot': plot,
      'imdb_rating': imdbRating,
    };
  }

  static EnrichedMention fromJson(Map<String, dynamic> json) {
    final rawType = TranscriptEnrichmentService._cleanText(json['type']);
    final normalizedType = TranscriptEnrichmentService._normalizeMentionType(
      rawType,
    );
    return EnrichedMention(
      title: TranscriptEnrichmentService._cleanText(
        json['title'] ?? json['name'],
      ),
      type: normalizedType,
      subtype: TranscriptEnrichmentService._cleanNullableText(
        json['subtype'] ?? (normalizedType == rawType ? null : rawType),
      ),
      creator: TranscriptEnrichmentService._cleanNullableText(
        json['creator'] ?? json['author'] ?? json['artist'],
      ),
      year: TranscriptEnrichmentService._cleanNullableText(json['year']),
      whyMentioned: TranscriptEnrichmentService._cleanNullableText(
        json['why_mentioned'] ?? json['reason'] ?? json['description'],
      ),
      posterUrl: TranscriptEnrichmentService._cleanNullableText(
        json['poster_url'] ??
            json['cover_url'] ??
            json['artwork_url'] ??
            json['image_url'],
      ),
      genres: TranscriptEnrichmentService._extractGenreList(
        json['genres'] ?? json['genre'],
      ),
      rawGenres: TranscriptEnrichmentService._extractGenreList(
        json['raw_genres'] ?? json['rawGenres'],
      ),
      catalogId: TranscriptEnrichmentService._cleanNullableText(
        json['catalog_id'] ?? json['catalogId'] ?? json['provider_id'],
      ),
      catalogSource: TranscriptEnrichmentService._cleanNullableText(
        json['catalog_source'] ?? json['catalogSource'] ?? json['provider'],
      ),
      city: TranscriptEnrichmentService._cleanNullableText(json['city']),
      country: TranscriptEnrichmentService._cleanNullableText(json['country']),
      latitude: TranscriptEnrichmentService._toDouble(
        json['latitude'] ?? json['lat'],
      ),
      longitude: TranscriptEnrichmentService._toDouble(
        json['longitude'] ?? json['lon'] ?? json['lng'],
      ),
      matchConfidence: TranscriptEnrichmentService._toDouble(
        json['match_confidence'] ?? json['matchConfidence'],
      ),
      libraryStatus: TranscriptEnrichmentService._cleanNullableText(
        json['user_library_status'] ?? json['userLibraryStatus'],
      ),
      pageCount: _positiveInt(
        json['page_count'] ??
            json['pageCount'] ??
            json['number_of_pages_median'] ??
            json['number_of_pages'],
      ),
      currentPage: _positiveInt(json['current_page'] ?? json['currentPage']),
      plot: TranscriptEnrichmentService._cleanNullableText(
        json['plot'] ?? json['overview'],
      ),
      imdbRating: TranscriptEnrichmentService._toDouble(
        json['imdb_rating'] ?? json['imdbRating'],
      ),
    );
  }

  static int? _positiveInt(Object? raw) {
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw.isFinite && raw > 0) return raw.round();
    final value = int.tryParse(raw?.toString().trim() ?? '');
    return value != null && value > 0 ? value : null;
  }
}

class EnrichedNotableItem {
  const EnrichedNotableItem({
    required this.text,
    required this.type,
    this.label,
    this.attribution,
    this.whyImportant,
    this.destinationUrl,
  });

  final String text;
  final String type;
  final String? label;
  final String? attribution;
  final String? whyImportant;
  final String? destinationUrl;

  bool get hasUsefulContent => text.trim().isNotEmpty;

  bool get isMusicItem {
    final descriptor = '${type.trim()} ${label?.trim() ?? ''}'.toLowerCase();
    return RegExp(
      r'\b(song|track|album|music|artist|band)\b',
    ).hasMatch(descriptor);
  }

  Uri? get websiteUri {
    if (type.trim().toLowerCase() != 'website') return null;

    return destinationUri;
  }

  Uri? get destinationUri {
    for (final candidate in [
      destinationUrl,
      if (type.trim().toLowerCase() == 'website') text,
      if (type.trim().toLowerCase() == 'website') label,
      if (type.trim().toLowerCase() == 'website') attribution,
    ]) {
      final value = candidate?.trim() ?? '';
      if (value.isEmpty) continue;
      final match = RegExp(
        r'''(?:https?://|www\.)[^\s<>"']+|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*\.)+[a-zA-Z]{2,})(?:/[^\s<>"']*)?''',
        caseSensitive: false,
      ).firstMatch(value);
      if (match == null) continue;

      final raw = match.group(0)!.replaceFirst(RegExp(r'[.,;:!?)\]}]+$'), '');
      final normalized = raw.toLowerCase().startsWith(RegExp(r'https?://'))
          ? raw
          : 'https://$raw';
      final uri = Uri.tryParse(normalized);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.contains('.') &&
          UrlSecurityValidator.hasAllowedPublicUrlSyntax(uri.toString())) {
        return uri;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type,
      'label': label,
      'attribution': attribution,
      'why_important': whyImportant,
      'url': destinationUrl,
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
      destinationUrl: TranscriptEnrichmentService._cleanNullableText(
        json['url'] ?? json['href'] ?? json['link'],
      ),
    );
  }
}
