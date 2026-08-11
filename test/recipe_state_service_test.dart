import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/recipe_state_service.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';

void main() {
  test('merged recipe source JSON remains round-trip compatible', () {
    const item = ShoppingListItem(
      id: 'garlic',
      recipeId: 1,
      recipeTitle: 'Pasta',
      ingredient: EnrichedRecipeIngredient(
        name: 'Garlic',
        quantity: '2',
        unit: 'cloves',
      ),
      mergedSources: [
        RecipeMergedSource(
          recipeId: 2,
          recipeTitle: 'Soup',
          quantityLabel: '4 cloves',
        ),
      ],
      mergedQuantityLabel: '6 cloves',
    );

    final encoded = jsonEncode(item.toJson());
    final restored = ShoppingListItem.fromJson(jsonDecode(encoded));

    expect(restored, isNotNull);
    expect(jsonEncode(restored!.toJson()), encoded);
    expect(restored.allRecipeTitles, ['Pasta', 'Soup']);
  });
}
