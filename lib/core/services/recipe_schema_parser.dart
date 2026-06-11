import 'dart:convert';

import 'package:html_unescape/html_unescape.dart';

import 'tag_noise_filter.dart';
import 'text_cleaner.dart';
import 'transcript_enrichment_service.dart';

class RecipeSchemaParser {
  RecipeSchemaParser._();

  static final _unescape = HtmlUnescape();

  static EnrichedRecipe? parse(
    String html, {
    required String pageUrl,
    String? fallbackTitle,
    String? fallbackImage,
    String? fallbackAuthor,
  }) {
    final structured = _parseJsonLd(html, pageUrl: pageUrl);
    if (structured != null) return structured;

    return _parseMicrodata(
      html,
      pageUrl: pageUrl,
      fallbackTitle: fallbackTitle,
      fallbackImage: fallbackImage,
      fallbackAuthor: fallbackAuthor,
    );
  }

  static EnrichedRecipe? _parseJsonLd(
    String html, {
    required String pageUrl,
  }) {
    final scripts = RegExp(
      r'''<script[^>]+type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in scripts) {
      final raw = match.group(1)?.trim() ?? '';
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        for (final node in _walkNodes(decoded)) {
          if (!_isRecipeNode(node)) continue;
          final recipe = _recipeFromJsonLd(node, pageUrl: pageUrl);
          if (recipe?.hasUsefulContent == true) return recipe;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Iterable<Map<String, dynamic>> _walkNodes(Object? value) sync* {
    if (value is List) {
      for (final item in value) {
        yield* _walkNodes(item);
      }
      return;
    }
    if (value is! Map) return;

    final map = Map<String, dynamic>.from(value);
    yield map;
    final graph = map['@graph'];
    if (graph != null) yield* _walkNodes(graph);
  }

  static bool _isRecipeNode(Map<String, dynamic> node) {
    final type = node['@type'];
    if (type is String) return type.toLowerCase() == 'recipe';
    if (type is List) {
      return type.any((item) => item.toString().toLowerCase() == 'recipe');
    }
    return false;
  }

  static EnrichedRecipe? _recipeFromJsonLd(
    Map<String, dynamic> json, {
    required String pageUrl,
  }) {
    final ingredients = _stringList(
      json['recipeIngredient'] ?? json['ingredients'],
    ).map(parseIngredient).where((item) => item.name.isNotEmpty).toList();
    final steps = _instructionSteps(
      json['recipeInstructions'] ?? json['instructions'],
    );
    final title = _text(json['name'] ?? json['headline']);
    if (title.isEmpty && ingredients.isEmpty && steps.isEmpty) return null;

    return EnrichedRecipe(
      title: title,
      description: _nullableText(json['description']),
      image: _imageUrl(json['image']),
      author: _personName(json['author']),
      source: _personName(json['publisher']) ?? Uri.tryParse(pageUrl)?.host,
      category: _nullableText(json['recipeCategory']),
      cuisine: _nullableText(json['recipeCuisine']),
      servings: _nullableText(json['recipeYield']),
      ingredients: ingredients,
      steps: steps,
      prepTime: _durationLabel(json['prepTime']),
      cookTime: _durationLabel(json['cookTime']),
      totalTime: _durationLabel(json['totalTime']),
      nutrition: RecipeNutrition.fromJsonOrNull(json['nutrition']),
      tags: TagNoiseFilter.filterTags(_keywords(json['keywords'])),
    );
  }

  static EnrichedRecipe? _parseMicrodata(
    String html, {
    required String pageUrl,
    String? fallbackTitle,
    String? fallbackImage,
    String? fallbackAuthor,
  }) {
    final lower = html.toLowerCase();
    final hasRecipeType = lower.contains('schema.org/recipe') ||
        lower.contains('itemtype="https://schema.org/recipe"') ||
        lower.contains("itemtype='https://schema.org/recipe'");
    if (!hasRecipeType) return null;

    final ingredientLines = _itemPropValues(html, 'recipeIngredient');
    final instructionLines = _itemPropValues(html, 'recipeInstructions');
    if (ingredientLines.length < 2 && instructionLines.isEmpty) return null;

    return EnrichedRecipe(
      title: _itemPropValues(html, 'name').firstOrNull ??
          fallbackTitle?.trim() ??
          '',
      description: _itemPropValues(html, 'description').firstOrNull,
      image: _itemPropValues(html, 'image').firstOrNull ?? fallbackImage,
      author:
          _itemPropValues(html, 'author').firstOrNull ?? fallbackAuthor,
      source: Uri.tryParse(pageUrl)?.host,
      category: _itemPropValues(html, 'recipeCategory').firstOrNull,
      cuisine: _itemPropValues(html, 'recipeCuisine').firstOrNull,
      servings: _itemPropValues(html, 'recipeYield').firstOrNull,
      ingredients: ingredientLines.map(parseIngredient).toList(),
      steps: instructionLines,
      prepTime:
          _durationLabel(_itemPropValues(html, 'prepTime').firstOrNull),
      cookTime:
          _durationLabel(_itemPropValues(html, 'cookTime').firstOrNull),
      totalTime:
          _durationLabel(_itemPropValues(html, 'totalTime').firstOrNull),
      nutrition: RecipeNutrition.fromJsonOrNull({
        'calories': _itemPropValues(html, 'calories').firstOrNull,
        'proteinContent': _itemPropValues(html, 'proteinContent').firstOrNull,
        'carbohydrateContent':
            _itemPropValues(html, 'carbohydrateContent').firstOrNull,
        'fatContent': _itemPropValues(html, 'fatContent').firstOrNull,
        'fiberContent': _itemPropValues(html, 'fiberContent').firstOrNull,
      }),
    );
  }

  static EnrichedRecipeIngredient parseIngredient(String raw) {
    var value = _text(raw);
    if (value.isEmpty) {
      return const EnrichedRecipeIngredient(name: '');
    }

    String? notes;
    final comma = value.indexOf(',');
    if (comma > 0 && comma < value.length - 1) {
      notes = value.substring(comma + 1).trim();
      value = value.substring(0, comma).trim();
    }

    final quantityMatch = RegExp(
      r'^((?:\d+\s+)?\d+/\d+|\d+(?:[.,]\d+)?|[¼½¾⅓⅔⅛⅜⅝⅞]+)\s*',
    ).firstMatch(value);
    final quantity = quantityMatch?.group(1);
    if (quantityMatch != null) {
      value = value.substring(quantityMatch.end).trim();
    }

    const units = {
      'cup',
      'cups',
      'tbsp',
      'tablespoon',
      'tablespoons',
      'tsp',
      'teaspoon',
      'teaspoons',
      'g',
      'gram',
      'grams',
      'kg',
      'ml',
      'l',
      'litre',
      'liter',
      'oz',
      'ounce',
      'ounces',
      'lb',
      'pound',
      'pounds',
      'clove',
      'cloves',
      'can',
      'cans',
      'packet',
      'packets',
      'pinch',
      'slice',
      'slices',
      'whole',
      'bunch',
      'sprig',
      'sprigs',
    };
    String? unit;
    final firstSpace = value.indexOf(' ');
    final firstWord =
        (firstSpace < 0 ? value : value.substring(0, firstSpace)).toLowerCase();
    if (units.contains(firstWord)) {
      unit = firstWord;
      value = firstSpace < 0 ? '' : value.substring(firstSpace + 1).trim();
    }

    return EnrichedRecipeIngredient(
      name: value.isEmpty ? _text(raw) : value,
      quantity: quantity,
      unit: unit,
      notes: notes,
    );
  }

  static List<String> _instructionSteps(Object? raw) {
    final out = <String>[];
    void add(Object? value) {
      if (value is String) {
        final text = _text(value);
        if (text.isNotEmpty) out.add(text);
      } else if (value is List) {
        for (final item in value) {
          add(item);
        }
      } else if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final nested = map['itemListElement'] ?? map['steps'];
        if (nested != null) {
          add(nested);
        } else {
          add(map['text'] ?? map['description'] ?? map['name']);
        }
      }
    }

    add(raw);
    return out.take(40).toList();
  }

  static List<String> _itemPropValues(String html, String property) {
    final escaped = RegExp.escape(property);
    final matches = RegExp(
      '''<[^>]+itemprop=["']$escaped["'][^>]*>([\\s\\S]*?)</[^>]+>|'''
      '''<[^>]+itemprop=["']$escaped["'][^>]+(?:content|datetime|src)=["']([^"']+)["'][^>]*>''',
      caseSensitive: false,
    ).allMatches(html);
    return matches
        .map((match) => _text(match.group(1) ?? match.group(2)))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) return raw.map(_text).where((item) => item.isNotEmpty).toList();
    final text = _text(raw);
    return text.isEmpty ? const [] : [text];
  }

  static List<String> _keywords(Object? raw) {
    if (raw is List) return raw.map(_text).where((item) => item.isNotEmpty).toList();
    return _text(raw)
        .split(RegExp(r'[,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String? _imageUrl(Object? raw) {
    if (raw is String) return _nullableText(raw);
    if (raw is List && raw.isNotEmpty) return _imageUrl(raw.first);
    if (raw is Map) {
      return _nullableText(raw['url'] ?? raw['contentUrl']);
    }
    return null;
  }

  static String? _personName(Object? raw) {
    if (raw is String) return _nullableText(raw);
    if (raw is List && raw.isNotEmpty) return _personName(raw.first);
    if (raw is Map) return _nullableText(raw['name']);
    return null;
  }

  static String? _durationLabel(Object? raw) {
    final value = _text(raw);
    if (value.isEmpty) return null;
    final match = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return value;
    final days = int.tryParse(match.group(1) ?? '') ?? 0;
    final hours = int.tryParse(match.group(2) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(3) ?? '') ?? 0;
    final parts = <String>[
      if (days > 0) '${days}d',
      if (hours > 0) '${hours}h',
      if (minutes > 0) '$minutes min',
    ];
    return parts.isEmpty ? value : parts.join(' ');
  }

  static String _text(Object? raw) {
    if (raw == null) return '';
    final withoutTags = raw
        .toString()
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return TextCleaner.cleanLoose(_unescape.convert(withoutTags));
  }

  static String? _nullableText(Object? raw) {
    final value = _text(raw);
    return value.isEmpty ? null : value;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
