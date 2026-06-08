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
  });

  final String id;
  final int recipeId;
  final String recipeTitle;
  final EnrichedRecipeIngredient ingredient;
  final bool isChecked;

  ShoppingListItem copyWith({bool? isChecked}) {
    return ShoppingListItem(
      id: id,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      ingredient: ingredient,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_id': recipeId,
        'recipe_title': recipeTitle,
        'ingredient': ingredient.toJson(),
        'is_checked': isChecked,
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
    return ShoppingListItem(
      id: id,
      recipeId: (json['recipe_id'] as num?)?.toInt() ?? 0,
      recipeTitle: json['recipe_title']?.toString().trim() ?? 'Recipe',
      ingredient: ingredient,
      isChecked: json['is_checked'] == true,
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

  static String ingredientKey(
    EnrichedRecipeIngredient ingredient,
    int index,
  ) {
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

  Future<int> addToShoppingList({
    required int recipeId,
    required String recipeTitle,
    required List<MapEntry<int, EnrichedRecipeIngredient>> ingredients,
  }) async {
    final items = shoppingList();
    final existingIds = items.map((item) => item.id).toSet();
    var added = 0;
    for (final entry in ingredients) {
      final key = ingredientKey(entry.value, entry.key);
      final id = '${recipeId}_$key';
      if (!existingIds.add(id)) continue;
      items.add(
        ShoppingListItem(
          id: id,
          recipeId: recipeId,
          recipeTitle: recipeTitle,
          ingredient: entry.value,
        ),
      );
      added++;
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
