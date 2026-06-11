import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/recipe_schema_parser.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';

void main() {
  group('Recipe nutrition parsing', () {
    test('parses schema.org nutrition aliases with unit strings', () {
      final nutrition = RecipeNutrition.fromJsonOrNull({
        'calorieContent': '420 calories',
        'proteinContent': '18 g',
        'carbohydrateContent': '52g',
        'fatContent': '14 grams',
        'fiberContent': '6 g',
        'confidence': 0.72,
      });

      expect(nutrition, isNotNull);
      expect(nutrition!.calories, 420);
      expect(nutrition.proteinG, 18);
      expect(nutrition.carbsG, 52);
      expect(nutrition.fatG, 14);
      expect(nutrition.fiberG, 6);
      expect(nutrition.confidence, 0.72);
    });

    test('parses JSON-LD recipe nutrition into enriched recipe', () {
      const html = '''
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Paneer Bowl",
  "recipeIngredient": ["100 g paneer", "1 cup rice"],
  "recipeInstructions": ["Cook rice", "Top with paneer"],
  "nutrition": {
    "@type": "NutritionInformation",
    "calories": "510 kcal",
    "proteinContent": "24 g",
    "carbohydrateContent": "58 g",
    "fatContent": "20 g",
    "fiberContent": "4 g"
  }
}
</script>
''';

      final recipe = RecipeSchemaParser.parse(
        html,
        pageUrl: 'https://example.com/paneer-bowl',
      );

      expect(recipe, isNotNull);
      expect(recipe!.nutrition?.calories, 510);
      expect(recipe.nutrition?.proteinG, 24);
      expect(recipe.nutrition?.carbsG, 58);
      expect(recipe.nutrition?.fatG, 20);
      expect(recipe.nutrition?.fiberG, 4);
    });
  });
}
