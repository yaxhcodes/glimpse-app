import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/recipe_nutrition_service.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';

void main() {
  group('RecipeNutritionService', () {
    test('normalizes names and calculates per-serving nutrition', () async {
      final service = RecipeNutritionService(
        dataSource: _FakeNutritionDataSource({
          'ground beef': const FoodNutrition(
            name: 'ground beef',
            calories: 254,
            proteinG: 26,
            carbsG: 0,
            fatG: 17,
            fiberG: 0,
          ),
          'olive oil': const FoodNutrition(
            name: 'olive oil',
            calories: 884,
            proteinG: 0,
            carbsG: 0,
            fatG: 100,
            fiberG: 0,
          ),
        }),
      );

      const recipe = EnrichedRecipe(
        title: 'Beef Bowls',
        servings: '8',
        ingredients: [
          EnrichedRecipeIngredient(
            name: 'beef mince',
            quantity: '1000',
            unit: 'g',
          ),
          EnrichedRecipeIngredient(
            name: 'extra virgin olive oil',
            quantity: '45',
            unit: 'ml',
          ),
        ],
      );

      final nutrition = await service.calculate(
        recipe: recipe,
        estimatedServings: null,
      );

      expect(nutrition, isNotNull);
      expect(nutrition!.source, RecipeNutritionSource.calculated);
      expect(nutrition.servings, 8);
      expect(nutrition.calories, closeTo(367.225, 0.01));
      expect(nutrition.proteinG, closeTo(32.5, 0.01));
      expect(nutrition.fatG, closeTo(26.875, 0.01));
      expect(nutrition.unmatchedIngredients, isEmpty);
    });

    test(
      'skips unmatched ingredients without failing recipe nutrition',
      () async {
        final service = RecipeNutritionService(
          dataSource: _FakeNutritionDataSource({
            'onion': const FoodNutrition(
              name: 'onion',
              calories: 40,
              proteinG: 1.1,
              carbsG: 9.3,
              fatG: 0.1,
              fiberG: 1.7,
            ),
          }),
        );

        const recipe = EnrichedRecipe(
          title: 'Sauce',
          ingredients: [
            EnrichedRecipeIngredient(name: 'Onion', quantity: '300', unit: 'g'),
            EnrichedRecipeIngredient(
              name: 'Chinese black vinegar',
              quantity: '20',
              unit: 'ml',
            ),
          ],
        );

        final nutrition = await service.calculate(
          recipe: recipe,
          estimatedServings: 2,
        );

        expect(nutrition, isNotNull);
        expect(nutrition!.calories, 60);
        expect(nutrition.unmatchedIngredients, ['Chinese black vinegar']);
      },
    );

    test(
      'uses deterministic adult portions when quantities are missing',
      () async {
        final service = RecipeNutritionService(
          dataSource: _FakeNutritionDataSource({
            'potato': const FoodNutrition(
              name: 'potato',
              calories: 77,
              proteinG: 2,
              carbsG: 17,
              fatG: 0.1,
              fiberG: 2.2,
            ),
            'atta': const FoodNutrition(
              name: 'atta',
              calories: 340,
              proteinG: 13,
              carbsG: 72,
              fatG: 2.5,
              fiberG: 11,
            ),
          }),
        );

        const recipe = EnrichedRecipe(
          title: 'Aloo Paratha',
          ingredients: [
            EnrichedRecipeIngredient(name: 'Potato'),
            EnrichedRecipeIngredient(name: 'Atta'),
          ],
        );

        final nutrition = await service.calculate(
          recipe: recipe,
          estimatedServings: 1,
        );

        expect(nutrition, isNotNull);
        expect(nutrition!.calories, closeTo(296.4, 0.01));
        expect(nutrition.proteinG, closeTo(10.2, 0.01));
        expect(nutrition.confidence, lessThan(0.7));
        expect(nutrition.unmatchedIngredients, isEmpty);
      },
    );

    test('infers servings and parses common recipe units', () async {
      final service = RecipeNutritionService(
        dataSource: _FakeNutritionDataSource({
          'chicken': const FoodNutrition(
            name: 'chicken',
            calories: 215,
            proteinG: 18,
            carbsG: 0,
            fatG: 15,
            fiberG: 0,
          ),
          'coconut': const FoodNutrition(
            name: 'coconut',
            calories: 660,
            proteinG: 7,
            carbsG: 24,
            fatG: 65,
            fiberG: 16,
          ),
          'curd': const FoodNutrition(
            name: 'curd',
            calories: 61,
            proteinG: 3.5,
            carbsG: 4.7,
            fatG: 3.3,
            fiberG: 0,
          ),
          'onion': const FoodNutrition(
            name: 'onion',
            calories: 40,
            proteinG: 1.1,
            carbsG: 9.3,
            fatG: 0.1,
            fiberG: 1.7,
          ),
        }),
      );

      const recipe = EnrichedRecipe(
        title: 'Chicken Curry',
        ingredients: [
          EnrichedRecipeIngredient(
            name: 'bone-in chicken',
            quantity: '500',
            unit: 'g',
          ),
          EnrichedRecipeIngredient(
            name: 'desiccated coconut',
            quantity: '3',
            unit: 'tbsp',
          ),
          EnrichedRecipeIngredient(
            name: 'thick curd',
            quantity: '1/2',
            unit: 'cup',
          ),
          EnrichedRecipeIngredient(
            name: 'browned onions',
            quantity: '1',
            unit: 'cup',
          ),
        ],
      );

      final nutrition = await service.calculate(
        recipe: recipe,
        estimatedServings: null,
      );

      expect(nutrition, isNotNull);
      expect(nutrition!.servings, 3);
      expect(nutrition.calories, closeTo(513.73, 0.1));
      expect(nutrition.proteinG, closeTo(33.33, 0.1));
      expect(nutrition.unmatchedIngredients, isEmpty);
    });
  });
}

class _FakeNutritionDataSource implements NutritionDataSource {
  _FakeNutritionDataSource(this.foods);

  final Map<String, FoodNutrition> foods;

  @override
  Future<FoodNutrition?> lookup(String normalizedIngredientName) async {
    return foods[normalizedIngredientName];
  }
}
