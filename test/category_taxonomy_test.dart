import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/category_taxonomy.dart';

void main() {
  test(
    'category evidence matches whole words, including later occurrences',
    () {
      for (final text in ['car', '(car)', 'career, then car', 'car-care']) {
        expect(
          CategoryTaxonomy.inferAdditionalCategories(
            tags: const [],
            text: text,
          ),
          contains('Vehicles'),
          reason: text,
        );
      }
      for (final text in ['career', 'scar', 'car2', '2car', 'scarcity']) {
        expect(
          CategoryTaxonomy.inferAdditionalCategories(
            tags: const [],
            text: text,
          ),
          isNot(contains('Vehicles')),
          reason: text,
        );
      }
    },
  );

  test('category evidence preserves phrase boundaries', () {
    expect(
      CategoryTaxonomy.inferAdditionalCategories(
        tags: const [],
        text: 'A (tv show) recommendation',
      ),
      contains('Movies & TV'),
    );
    expect(
      CategoryTaxonomy.inferAdditionalCategories(
        tags: const [],
        text: 'A tv showcase',
      ),
      isNot(contains('Movies & TV')),
    );
  });

  test('spiritual legacy labels normalize to Philosophy', () {
    final result = CategoryTaxonomy.normalize(
      category: 'Non-duality',
      tags: const ['Advaita Vedanta', 'Brahman', 'salt doll parable'],
    );

    expect(result.name, 'Philosophy');
  });

  test('Advaita tags do not substring-match into Technology', () {
    final result = CategoryTaxonomy.normalize(
      category: 'Unmapped creator label',
      tags: const ['Advaita Vedanta', 'Brahman'],
    );

    expect(result.name, isNot('Technology'));
    expect(result.name, 'Other');
  });

  test('sports legacy labels normalize to Sports', () {
    final result = CategoryTaxonomy.normalize(category: 'Cricket');

    expect(result.name, 'Sports');
  });
}
