import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'transcript_enrichment_service.dart';

class RecipeNutritionService {
  RecipeNutritionService({
    required NutritionDataSource dataSource,
    IngredientNameNormalizer normalizer = const IngredientNameNormalizer(),
    IngredientPortionResolver portionResolver =
        const IngredientPortionResolver(),
  }) : _dataSource = dataSource,
       _normalizer = normalizer,
       _portionResolver = portionResolver;

  final NutritionDataSource _dataSource;
  final IngredientNameNormalizer _normalizer;
  final IngredientPortionResolver _portionResolver;

  Future<RecipeNutrition?> calculate({
    required EnrichedRecipe recipe,
    required int? estimatedServings,
  }) async {
    final servings =
        _explicitServings(recipe) ??
        estimatedServings ??
        _inferServingsFromIngredients(recipe);
    if (servings == null || servings <= 0 || recipe.ingredients.isEmpty) {
      return null;
    }

    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var fiber = 0.0;
    var matched = 0;
    final unmatched = <String>[];
    var explicitAmounts = 0;

    for (final ingredient in recipe.ingredients) {
      final normalizedName = _normalizer.normalize(ingredient.name);
      final explicitAmount = IngredientAmount.fromIngredient(ingredient);
      final amount = explicitAmount ?? _portionResolver.resolve(normalizedName);
      if (amount == null) {
        unmatched.add(ingredient.name);
        continue;
      }
      if (explicitAmount != null) explicitAmounts++;

      final food = await _dataSource.lookup(normalizedName);
      if (food == null) {
        unmatched.add(ingredient.name);
        continue;
      }

      final factor = amount.metricQuantity / 100;
      calories += food.calories * factor;
      protein += food.proteinG * factor;
      carbs += food.carbsG * factor;
      fat += food.fatG * factor;
      fiber += food.fiberG * factor;
      matched++;
    }

    if (matched == 0 || calories <= 0) return null;

    return RecipeNutrition(
      calories: calories / servings,
      proteinG: protein / servings,
      carbsG: carbs / servings,
      fatG: fat / servings,
      fiberG: fiber / servings,
      confidence:
          (matched / recipe.ingredients.length) *
          (explicitAmounts == matched ? 0.9 : 0.62),
      isEstimated: true,
      servings: servings,
      source: RecipeNutritionSource.calculated,
      unmatchedIngredients: unmatched,
    );
  }

  int? _explicitServings(EnrichedRecipe recipe) {
    final text = recipe.servings?.trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    final direct = RegExp(r'\b(\d+)\b').firstMatch(text);
    final parsed = int.tryParse(direct?.group(1) ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? _inferServingsFromIngredients(EnrichedRecipe recipe) {
    double? largestMainProtein;
    for (final ingredient in recipe.ingredients) {
      final normalizedName = _normalizer.normalize(ingredient.name);
      if (!_looksLikeMainProtein(normalizedName)) continue;
      final amount = IngredientAmount.fromIngredient(ingredient);
      if (amount == null) continue;
      largestMainProtein = largestMainProtein == null
          ? amount.metricQuantity
          : largestMainProtein > amount.metricQuantity
          ? largestMainProtein
          : amount.metricQuantity;
    }
    if (largestMainProtein == null) return null;
    return (largestMainProtein / 150).round().clamp(1, 12);
  }

  bool _looksLikeMainProtein(String normalizedName) {
    return RegExp(
      r'\b(chicken|beef|lamb|mutton|fish|prawn|shrimp|paneer|tofu|pork|turkey)\b',
    ).hasMatch(normalizedName);
  }
}

class IngredientAmount {
  const IngredientAmount({required this.metricQuantity});

  /// Quantity in grams or milliliters. Nutrition data is expected per 100 g/ml.
  final double metricQuantity;

  static IngredientAmount? fromIngredient(EnrichedRecipeIngredient ingredient) {
    final quantity = _parseNumber(ingredient.quantity);
    final unit = (ingredient.unit ?? '').trim().toLowerCase();
    if (quantity != null && unit.isNotEmpty) {
      return _fromQuantityAndUnit(quantity, unit);
    }

    final measure = ingredient.legacyMeasure?.trim();
    if (measure == null || measure.isEmpty) return null;
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?|\d+\s*/\s*\d+|\d+\s+\d+\s*/\s*\d+|\d+(?:[.,]\d+)?\s*[-–]\s*\d+(?:[.,]\d+)?)\s*(g|gram|grams|kg|ml|milliliter|milliliters|l|liter|liters|cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons)\b',
      caseSensitive: false,
    ).firstMatch(measure);
    if (match == null) return null;

    final parsed = _parseNumber(match.group(1));
    if (parsed == null) return null;
    return _fromQuantityAndUnit(parsed, match.group(2)!.toLowerCase());
  }

  static IngredientAmount? _fromQuantityAndUnit(double quantity, String unit) {
    return switch (unit) {
      'g' || 'gram' || 'grams' => IngredientAmount(metricQuantity: quantity),
      'kg' => IngredientAmount(metricQuantity: quantity * 1000),
      'ml' ||
      'milliliter' ||
      'milliliters' => IngredientAmount(metricQuantity: quantity),
      'l' ||
      'liter' ||
      'liters' => IngredientAmount(metricQuantity: quantity * 1000),
      'cup' || 'cups' => IngredientAmount(metricQuantity: quantity * 240),
      'tbsp' ||
      'tablespoon' ||
      'tablespoons' => IngredientAmount(metricQuantity: quantity * 15),
      'tsp' ||
      'teaspoon' ||
      'teaspoons' => IngredientAmount(metricQuantity: quantity * 5),
      _ => null,
    };
  }

  static double? _parseNumber(String? value) {
    if (value == null) return null;
    final normalized = value.trim().replaceAll(',', '.');
    final direct = double.tryParse(normalized);
    if (direct != null && direct > 0) return direct;
    final fraction = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(normalized);
    if (fraction != null) {
      final numerator = double.tryParse(fraction.group(1)!);
      final denominator = double.tryParse(fraction.group(2)!);
      if (numerator != null && denominator != null && denominator > 0) {
        return numerator / denominator;
      }
    }
    final mixedFraction = RegExp(
      r'^(\d+)\s+(\d+)\s*/\s*(\d+)$',
    ).firstMatch(normalized);
    if (mixedFraction != null) {
      final whole = double.tryParse(mixedFraction.group(1)!);
      final numerator = double.tryParse(mixedFraction.group(2)!);
      final denominator = double.tryParse(mixedFraction.group(3)!);
      if (whole != null &&
          numerator != null &&
          denominator != null &&
          denominator > 0) {
        return whole + numerator / denominator;
      }
    }
    final range = RegExp(
      r'^(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)$',
    ).firstMatch(normalized);
    if (range != null) {
      final start = double.tryParse(range.group(1)!);
      final end = double.tryParse(range.group(2)!);
      if (start != null && end != null) return (start + end) / 2;
    }
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(normalized);
    final parsed = double.tryParse(match?.group(0) ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

class IngredientNameNormalizer {
  const IngredientNameNormalizer();

  static const _synonyms = <String, String>{
    'beef mince': 'ground beef',
    'minced beef': 'ground beef',
    'lamb mince': 'ground lamb',
    'minced lamb': 'ground lamb',
    'passata': 'tomato puree',
    'caster sugar': 'sugar',
    'fresh mozzarella': 'mozzarella',
    'extra virgin olive oil': 'olive oil',
    'evoo': 'olive oil',
    'bone in chicken': 'chicken',
    'bone-in chicken': 'chicken',
    'thick curd': 'curd',
    'browned onions': 'onion',
    'desiccated coconut': 'coconut',
    'kashmiri chili powder': 'chili powder',
    'kashmiri chilli powder': 'chili powder',
  };

  String normalize(String raw) {
    final cleaned = raw
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'\b(fresh|chopped|diced|minced|sliced|browned|bone-in|bone in)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final singularized = cleaned
        .split(' ')
        .map((word) {
          if (word.length > 3 && word.endsWith('ies')) {
            return '${word.substring(0, word.length - 3)}y';
          }
          if (word.length > 3 && word.endsWith('es')) {
            return word.substring(0, word.length - 2);
          }
          if (word.length > 3 && word.endsWith('s')) {
            return word.substring(0, word.length - 1);
          }
          return word;
        })
        .join(' ');
    return _synonyms[cleaned] ?? _synonyms[singularized] ?? singularized;
  }
}

class IngredientPortionResolver {
  const IngredientPortionResolver();

  IngredientAmount? resolve(String normalizedName) {
    final name = normalizedName.toLowerCase();
    if (_containsAny(name, const ['olive oil', 'oil', 'ghee', 'butter'])) {
      return const IngredientAmount(metricQuantity: 15);
    }
    if (_containsAny(name, const ['ground beef', 'ground lamb', 'chicken'])) {
      return const IngredientAmount(metricQuantity: 125);
    }
    if (_containsAny(name, const ['paneer', 'tofu', 'mozzarella'])) {
      return const IngredientAmount(metricQuantity: 100);
    }
    if (_containsAny(name, const [
      'kidney bean',
      'rajma',
      'chickpea',
      'lentil',
    ])) {
      return const IngredientAmount(metricQuantity: 120);
    }
    if (_containsAny(name, const ['potato', 'onion', 'tomato'])) {
      return const IngredientAmount(metricQuantity: 120);
    }
    if (_containsAny(name, const ['rice', 'pasta', 'noodle'])) {
      return const IngredientAmount(metricQuantity: 150);
    }
    if (_containsAny(name, const ['wrap', 'tortilla', 'roti', 'paratha'])) {
      return const IngredientAmount(metricQuantity: 70);
    }
    if (_containsAny(name, const ['flour', 'atta', 'dough'])) {
      return const IngredientAmount(metricQuantity: 60);
    }
    if (_containsAny(name, const ['sugar', 'honey'])) {
      return const IngredientAmount(metricQuantity: 12);
    }
    if (_containsAny(name, const ['curd', 'yogurt', 'yoghurt'])) {
      return const IngredientAmount(metricQuantity: 80);
    }
    if (_containsAny(name, const ['spice', 'masala', 'seasoning'])) {
      return const IngredientAmount(metricQuantity: 3);
    }
    return null;
  }

  static bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }
}

abstract class NutritionDataSource {
  Future<FoodNutrition?> lookup(String normalizedIngredientName);
}

class FoodNutrition {
  const FoodNutrition({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });

  final String name;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;

  Map<String, dynamic> toJson() => {
    'name': name,
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'fiber_g': fiberG,
  };

  static FoodNutrition? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final name = json['name']?.toString().trim() ?? '';
    final calories = _number(json['calories']);
    final protein = _number(json['protein_g']);
    final carbs = _number(json['carbs_g']);
    final fat = _number(json['fat_g']);
    final fiber = _number(json['fiber_g']);
    if (name.isEmpty ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        fiber == null) {
      return null;
    }
    return FoodNutrition(
      name: name,
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fiberG: fiber,
    );
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class CachedNutritionDataSource implements NutritionDataSource {
  CachedNutritionDataSource({required NutritionDataSource remote})
    : _remote = remote;

  static const _prefix = 'nutrition_lookup_v1:';

  final NutritionDataSource _remote;

  @override
  Future<FoodNutrition?> lookup(String normalizedIngredientName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$normalizedIngredientName';
    final cached = FoodNutrition.fromJson(
      jsonDecode(prefs.getString(key) ?? 'null'),
    );
    if (cached != null) return cached;

    final result = await _remote.lookup(normalizedIngredientName);
    if (result != null) {
      await prefs.setString(key, jsonEncode(result.toJson()));
    }
    return result;
  }
}

class UsdaFoodDataCentralDataSource implements NutritionDataSource {
  UsdaFoodDataCentralDataSource({required Dio dio, required String apiKey})
    : _dio = dio,
      _apiKey = apiKey;

  final Dio _dio;
  final String _apiKey;

  @override
  Future<FoodNutrition?> lookup(String normalizedIngredientName) async {
    if (_apiKey.trim().isEmpty) return null;
    try {
      final search = await _dio
          .get<Map<String, dynamic>>(
            'https://api.nal.usda.gov/fdc/v1/foods/search',
            queryParameters: {
              'api_key': _apiKey,
              'query': normalizedIngredientName,
              'pageSize': 1,
              'dataType': ['Foundation', 'SR Legacy', 'Survey (FNDDS)'],
            },
            options: Options(
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
            ),
          )
          .timeout(const Duration(seconds: 8));
      final foods = search.data?['foods'];
      if (foods is! List || foods.isEmpty || foods.first is! Map) return null;

      final nutrients = Map<String, dynamic>.from(foods.first as Map);
      return _fromFoodSearchResult(
        normalizedIngredientName,
        nutrients['foodNutrients'],
      );
    } catch (error, stack) {
      developer.log(
        'USDA nutrition lookup failed for $normalizedIngredientName: $error',
        name: 'RecipeNutrition',
        stackTrace: stack,
      );
      return null;
    }
  }

  FoodNutrition? _fromFoodSearchResult(String name, Object? rawNutrients) {
    if (rawNutrients is! List) return null;
    double nutrient(String nutrientName, {String? unitName}) {
      for (final item in rawNutrients) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);
        final label = json['nutrientName']?.toString().toLowerCase() ?? '';
        final unit = json['unitName']?.toString().toLowerCase() ?? '';
        if (label == nutrientName &&
            (unitName == null || unit == unitName.toLowerCase())) {
          return (json['value'] as num?)?.toDouble() ?? 0;
        }
      }
      return 0;
    }

    return FoodNutrition(
      name: name,
      calories: nutrient('energy', unitName: 'kcal'),
      proteinG: nutrient('protein'),
      carbsG: nutrient('carbohydrate, by difference'),
      fatG: nutrient('total lipid (fat)'),
      fiberG: nutrient('fiber, total dietary'),
    );
  }
}
