import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'transcript_enrichment_service.dart';

class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    required this.ingredient,
    this.isChecked = false,
    this.mergedSources = const [],
    this.mergedQuantityLabel,
  });

  final String id;
  final int recipeId;
  final String recipeTitle;
  final EnrichedRecipeIngredient ingredient;
  final bool isChecked;

  /// Additional recipe sources merged into this item (name + title pairs).
  final List<RecipeMergedSource> mergedSources;

  /// Combined quantity label when multiple recipes contributed (e.g. "6 cloves").
  final String? mergedQuantityLabel;

  /// All recipe titles contributing to this ingredient (primary + merged).
  List<String> get allRecipeTitles => {
    recipeTitle,
    ...mergedSources.map((source) => source.recipeTitle),
  }.toList();

  bool get isMerged => mergedSources.isNotEmpty;

  ShoppingListItem copyWith({
    bool? isChecked,
    List<RecipeMergedSource>? mergedSources,
    String? mergedQuantityLabel,
  }) {
    return ShoppingListItem(
      id: id,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      ingredient: ingredient,
      isChecked: isChecked ?? this.isChecked,
      mergedSources: mergedSources ?? this.mergedSources,
      mergedQuantityLabel: mergedQuantityLabel ?? this.mergedQuantityLabel,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipe_id': recipeId,
    'recipe_title': recipeTitle,
    'ingredient': ingredient.toJson(),
    'is_checked': isChecked,
    if (mergedSources.isNotEmpty)
      'merged_sources': mergedSources.map((s) => s.toJson()).toList(),
    if (mergedQuantityLabel != null)
      'merged_quantity_label': mergedQuantityLabel,
  };

  static ShoppingListItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final ingredientRaw = json['ingredient'];
    if (ingredientRaw is! Map) return null;
    final ingredientJson = Map<String, dynamic>.from(ingredientRaw);
    final ingredient = EnrichedRecipeIngredient(
      name: ingredientJson['name']?.toString().trim() ?? '',
      quantity: ingredientJson['quantity']?.toString().trim(),
      unit: ingredientJson['unit']?.toString().trim(),
      notes: ingredientJson['notes']?.toString().trim(),
      legacyMeasure: ingredientJson['measure']?.toString().trim(),
    );
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty || ingredient.name.isEmpty) return null;
    final rawMerged = json['merged_sources'];
    final mergedSources = rawMerged is List
        ? rawMerged
              .map(RecipeMergedSource.fromJson)
              .whereType<RecipeMergedSource>()
              .toList()
        : const <RecipeMergedSource>[];
    return ShoppingListItem(
      id: id,
      recipeId: (json['recipe_id'] as num?)?.toInt() ?? 0,
      recipeTitle: json['recipe_title']?.toString().trim() ?? 'Recipe',
      ingredient: ingredient,
      isChecked: json['is_checked'] == true,
      mergedSources: mergedSources,
      mergedQuantityLabel: json['merged_quantity_label']?.toString().trim(),
    );
  }
}

class RecipeMergedSource {
  const RecipeMergedSource({
    required this.recipeId,
    required this.recipeTitle,
    this.quantityLabel,
  });

  final int recipeId;
  final String recipeTitle;
  final String? quantityLabel;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'recipe_title': recipeTitle,
    if (quantityLabel != null) 'quantity_label': quantityLabel,
  };

  static RecipeMergedSource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final title = json['recipe_title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;
    return RecipeMergedSource(
      recipeId: (json['recipe_id'] as num?)?.toInt() ?? 0,
      recipeTitle: title,
      quantityLabel: json['quantity_label']?.toString().trim(),
    );
  }
}

class RecipeStateService {
  RecipeStateService._(this._prefs);

  static const _checkedPrefix = 'glimpse_recipe_checked_v1_';
  static const _shoppingListKey = 'glimpse_recipe_shopping_list_v1';

  final SharedPreferences _prefs;

  static Future<RecipeStateService> create() async {
    return RecipeStateService._(await SharedPreferences.getInstance());
  }

  static String ingredientKey(EnrichedRecipeIngredient ingredient, int index) {
    final normalized = ingredient.displayText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${index}_$normalized';
  }

  Set<String> checkedIngredientKeys(int recipeId) {
    return (_prefs.getStringList('$_checkedPrefix$recipeId') ?? const [])
        .toSet();
  }

  Future<void> setIngredientChecked(
    int recipeId,
    String ingredientKey,
    bool checked,
  ) async {
    final values = checkedIngredientKeys(recipeId);
    checked ? values.add(ingredientKey) : values.remove(ingredientKey);
    await _prefs.setStringList(
      '$_checkedPrefix$recipeId',
      values.toList()..sort(),
    );
  }

  Future<void> setAllIngredientsChecked(
    int recipeId,
    Iterable<String> ingredientKeys,
  ) async {
    final values = ingredientKeys.toSet().toList()..sort();
    await _prefs.setStringList('$_checkedPrefix$recipeId', values);
  }

  Future<void> resetIngredientChecks(int recipeId) {
    return _prefs.remove('$_checkedPrefix$recipeId');
  }

  List<ShoppingListItem> shoppingList() {
    final raw = _prefs.getString(_shoppingListKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(ShoppingListItem.fromJson)
          .whereType<ShoppingListItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns a normalized key for deduplication by ingredient name.
  /// Two ingredients with the same canonical name are considered the same item.
  static String _canonicalName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Merges [quantity] labels into a combined total label where possible.
  /// Falls back to concatenation if numeric addition isn't feasible.
  static String? _mergeQuantityLabels(String? existing, String? incoming) {
    if (existing == null || existing.isEmpty) return incoming;
    if (incoming == null || incoming.isEmpty) return existing;
    // Try to extract numeric values and unit from both
    final numRe = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(.*)$');
    final mA = numRe.firstMatch(existing.trim());
    final mB = numRe.firstMatch(incoming.trim());
    if (mA != null && mB != null) {
      final unitA = mA.group(2)?.trim() ?? '';
      final unitB = mB.group(2)?.trim() ?? '';
      if (unitA.toLowerCase() == unitB.toLowerCase()) {
        final a = double.tryParse(mA.group(1)!.replaceAll(',', '.'));
        final b = double.tryParse(mB.group(1)!.replaceAll(',', '.'));
        if (a != null && b != null) {
          final sum = a + b;
          final sumStr = sum == sum.truncateToDouble()
              ? sum.toInt().toString()
              : sum.toStringAsFixed(1);
          return unitA.isEmpty ? sumStr : '$sumStr $unitA';
        }
      }
    }
    return '$existing + $incoming';
  }

  Future<int> addToShoppingList({
    required int recipeId,
    required String recipeTitle,
    required List<MapEntry<int, EnrichedRecipeIngredient>> ingredients,
  }) async {
    final items = shoppingList();
    // Build a map from canonical ingredient name to its list index for merging.
    final nameIndex = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      nameIndex[_canonicalName(items[i].ingredient.name)] = i;
    }
    final existingIds = items.map((item) => item.id).toSet();
    var added = 0;
    for (final entry in ingredients) {
      final key = ingredientKey(entry.value, entry.key);
      final id = '${recipeId}_$key';
      final canonical = _canonicalName(entry.value.name);

      if (nameIndex.containsKey(canonical)) {
        // Ingredient already present — merge into existing entry
        final idx = nameIndex[canonical]!;
        final existing = items[idx];
        // Avoid re-merging the exact same recipe+key combination
        if (!existingIds.contains(id)) {
          existingIds.add(id);
          final incomingQty = entry.value.amountLabel.trim();
          final mergedQty = _mergeQuantityLabels(
            existing.mergedQuantityLabel ?? existing.ingredient.amountLabel,
            incomingQty,
          );
          final newSource = RecipeMergedSource(
            recipeId: recipeId,
            recipeTitle: recipeTitle,
            quantityLabel: incomingQty.isEmpty ? null : incomingQty,
          );
          items[idx] = existing.copyWith(
            mergedSources: [...existing.mergedSources, newSource],
            mergedQuantityLabel: mergedQty,
          );
          added++;
        }
      } else {
        // New ingredient
        if (!existingIds.add(id)) continue;
        final newItem = ShoppingListItem(
          id: id,
          recipeId: recipeId,
          recipeTitle: recipeTitle,
          ingredient: entry.value,
        );
        items.add(newItem);
        nameIndex[canonical] = items.length - 1;
        added++;
      }
    }
    await _writeShoppingList(items);
    return added;
  }

  Future<void> setShoppingItemChecked(String id, bool checked) async {
    final items = shoppingList()
        .map((item) => item.id == id ? item.copyWith(isChecked: checked) : item)
        .toList();
    await _writeShoppingList(items);
  }

  Future<void> removeShoppingItem(String id) async {
    final items = shoppingList().where((item) => item.id != id).toList();
    await _writeShoppingList(items);
  }

  Future<void> clearShoppingList() {
    return _prefs.remove(_shoppingListKey);
  }

  Future<void> _writeShoppingList(List<ShoppingListItem> items) {
    return _prefs.setString(
      _shoppingListKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
