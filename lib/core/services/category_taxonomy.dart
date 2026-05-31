class CategoryDefinition {
  final String name;
  final String emoji;

  const CategoryDefinition(this.name, this.emoji);
}

/// Keeps top-level categories stable while allowing specific topics to live in tags.
class CategoryTaxonomy {
  static const categories = <CategoryDefinition>[
    CategoryDefinition('Technology', '💻'),
    CategoryDefinition('Business', '💼'),
    CategoryDefinition('Finance', '💰'),
    CategoryDefinition('Science', '🔬'),
    CategoryDefinition('Health', '❤️'),
    CategoryDefinition('Education', '📘'),
    CategoryDefinition('News', '📰'),
    CategoryDefinition('Design', '🎨'),
    CategoryDefinition('Home & Garden', '🌿'),
    CategoryDefinition('Food & Cooking', '🍳'),
    CategoryDefinition('Travel', '🌍'),
    CategoryDefinition('Entertainment', '🎬'),
    CategoryDefinition('Lifestyle', '✨'),
    CategoryDefinition('Shopping', '🛒'),
    CategoryDefinition('Reference', '📚'),
    CategoryDefinition('Other', '🔖'),
  ];

  static String promptOptions() {
    return categories.map((c) => '- ${c.name} (${c.emoji})').join('\n');
  }

  static CategoryDefinition normalize({
    required String category,
    String? emoji,
    List<String> tags = const [],
  }) {
    final normalizedInput = category.trim().toLowerCase();

    for (final option in categories) {
      if (option.name.toLowerCase() == normalizedInput) {
        return option;
      }
    }

    final synonymMap = <String, String>{
      'programming': 'Technology',
      'software': 'Technology',
      'developer': 'Technology',
      'coding': 'Technology',
      'startup': 'Business',
      'marketing': 'Business',
      'investing': 'Finance',
      'crypto': 'Finance',
      'economics': 'Finance',
      'research': 'Science',
      'ai': 'Technology',
      'machine learning': 'Technology',
      'medicine': 'Health',
      'fitness': 'Health',
      'learning': 'Education',
      'course': 'Education',
      'tutorial': 'Education',
      'politics': 'News',
      'world news': 'News',
      'ux': 'Design',
      'ui': 'Design',
      'gardening': 'Home & Garden',
      'home': 'Home & Garden',
      'food': 'Food & Cooking',
      'cooking': 'Food & Cooking',
      'recipe': 'Food & Cooking',
      'nutrition': 'Health',
      'movies': 'Entertainment',
      'music': 'Entertainment',
      'gaming': 'Entertainment',
      'books': 'Reference',
      'documentation': 'Reference',
      'productivity': 'Lifestyle',
      'self improvement': 'Lifestyle',
      'fashion': 'Lifestyle',
      'ecommerce': 'Shopping',
      'shopping': 'Shopping',
    };

    if (synonymMap.containsKey(normalizedInput)) {
      return byName(synonymMap[normalizedInput]!);
    }

    final searchable = [normalizedInput, ...tags.map((tag) => tag.toLowerCase())]
        .join(' ');

    if (_containsAny(searchable, ['react', 'flutter', 'dart', 'javascript', 'webdev', 'software', 'code'])) {
      return byName('Technology');
    }
    if (_containsAny(searchable, ['invest', 'stock', 'crypto', 'bank', 'money'])) {
      return byName('Finance');
    }
    if (_containsAny(searchable, ['garden', 'plants', 'balcony', 'compost', 'tomato'])) {
      return byName('Home & Garden');
    }
    if (_containsAny(searchable, [
      'recipe',
      'kitchen',
      'cook',
      'bake',
      'meal',
      'food',
      'food hacks',
      'vegan',
      'vegetarian',
      'dairy',
      'paneer',
      'protein',
      'plant-based',
      'smoothie',
      'dessert',
    ])) {
      return byName('Food & Cooking');
    }
    if (_containsAny(searchable, ['design', 'figma', 'brand', 'typography', 'ux', 'ui'])) {
      return byName('Design');
    }
    if (_containsAny(searchable, [
      'health',
      'fitness',
      'nutrition',
      'sleep',
      'medicine',
      'protein',
      'plant-based',
      'vegan',
      'calcium',
      'healthy',
    ])) {
      return byName('Health');
    }
    if (_containsAny(searchable, ['learn', 'study', 'course', 'lesson', 'tutorial'])) {
      return byName('Education');
    }
    if (_containsAny(searchable, ['news', 'election', 'policy', 'breaking'])) {
      return byName('News');
    }

    if (emoji != null && emoji.isNotEmpty) {
      for (final option in categories) {
        if (option.emoji == emoji) {
          return option;
        }
      }
    }

    return byName('Other');
  }

  static List<String> inferAdditionalCategories({
    required List<String> tags,
    String text = '',
  }) {
    final searchable = [text, ...tags].join(' ').toLowerCase();
    final inferred = <String>[];

    void add(String category) {
      if (!inferred.contains(category)) inferred.add(category);
    }

    if (_containsAny(searchable, [
      'recipe',
      'cook',
      'food',
      'meal',
      'vegan',
      'vegetarian',
      'dairy',
      'paneer',
      'protein',
      'plant-based',
      'smoothie',
      'dessert',
    ])) {
      add('Food & Cooking');
    }
    if (_containsAny(searchable, [
      'health',
      'nutrition',
      'fitness',
      'protein',
      'plant-based',
      'vegan',
      'calcium',
      'healthy',
    ])) {
      add('Health');
    }
    if (_containsAny(searchable, [
      'react',
      'flutter',
      'dart',
      'javascript',
      'software',
      'code',
      'artificial intelligence',
      'machine learning',
      'llm',
      'agent',
    ])) {
      add('Technology');
    }
    if (_containsAny(searchable, [
      'design',
      'figma',
      'typography',
      'ui',
      'ux',
    ])) {
      add('Design');
    }
    if (_containsAny(searchable, [
      'travel',
      'trek',
      'hike',
      'destination',
      'route',
    ])) {
      add('Travel');
    }
    if (_containsAny(searchable, [
      'movie',
      'film',
      'cinema',
      'music',
      'gaming',
      'anime',
    ])) {
      add('Entertainment');
    }

    return inferred;
  }

  static CategoryDefinition byName(String name) {
    return categories.firstWhere(
      (item) => item.name == name,
      orElse: () => const CategoryDefinition('Other', '🔖'),
    );
  }

  static CategoryDefinition? tryByName(String name) {
    for (final item in categories) {
      if (item.name == name) {
        return item;
      }
    }
    return null;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }
}
