import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/category_taxonomy.dart';

void main() {
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
