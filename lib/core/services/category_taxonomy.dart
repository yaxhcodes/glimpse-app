class CategoryDefinition {
  final String name;
  final String emoji;

  const CategoryDefinition(this.name, this.emoji);
}

/// Keeps top-level Interests stable while allowing specific subjects to live in
/// tags/topics. Older granular category names are still accepted as aliases so
/// existing saves and enrichment payloads do not need a storage migration.
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
    CategoryDefinition('History', '🏺'),
    CategoryDefinition('Philosophy', '🕯️'),
    CategoryDefinition('Nature', '🌿'),
    CategoryDefinition('Food', '🍳'),
    CategoryDefinition('Travel', '🌍'),
    CategoryDefinition('Entertainment', '🎬'),
    CategoryDefinition('Lifestyle', '✨'),
    CategoryDefinition('Sports', '🏅'),
    CategoryDefinition('Other', '🔖'),
  ];

  static const _interestAliases = <String, String>{
    'ai & ml': 'Technology',
    'software development': 'Technology',
    'gadgets & hardware': 'Technology',
    'apps & tools': 'Technology',
    'cybersecurity': 'Technology',
    'data & analytics': 'Technology',
    'startups': 'Business',
    'marketing & growth': 'Business',
    'creator economy': 'Business',
    'personal finance': 'Finance',
    'investing': 'Finance',
    'crypto': 'Finance',
    'space & astronomy': 'Science',
    'biology & medicine': 'Science',
    'fitness': 'Health',
    'nutrition': 'Health',
    'mental health': 'Health',
    'language learning': 'Education',
    'math': 'Education',
    'world affairs': 'News',
    'law & policy': 'News',
    'art & illustration': 'Design',
    'photography': 'Design',
    'architecture': 'Design',
    'history & culture': 'History',
    'spirituality & philosophy': 'Philosophy',
    'relationships': 'Lifestyle',
    'career': 'Business',
    'productivity': 'Lifestyle',
    'nature & environment': 'Nature',
    'parenting & family': 'Lifestyle',
    'home & garden': 'Lifestyle',
    'diy & making': 'Lifestyle',
    'food & cooking': 'Food',
    'restaurants & cafes': 'Food',
    'outdoors & adventure': 'Travel',
    'movies & tv': 'Entertainment',
    'music': 'Entertainment',
    'gaming': 'Entertainment',
    'fashion & beauty': 'Lifestyle',
    'shopping': 'Lifestyle',
    'vehicles': 'Lifestyle',
    'reference': 'Education',
    'books & literature': 'Education',
    'documentation': 'Education',
    'spirituality': 'Philosophy',
    'religion': 'Philosophy',
    'vedanta': 'Philosophy',
    'advaita': 'Philosophy',
    'advaita vedanta': 'Philosophy',
    'non-duality': 'Philosophy',
    'non duality': 'Philosophy',
    'non-dualism': 'Philosophy',
    'non dualism': 'Philosophy',
    'brahman': 'Philosophy',
    'dharma': 'Philosophy',
    'scripture': 'Philosophy',
    'sports': 'Sports',
    'cricket': 'Sports',
    'football': 'Sports',
    'basketball': 'Sports',
    'soccer': 'Sports',
    'tennis': 'Sports',
    'running': 'Sports',
    'athletics': 'Sports',
  };

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
      'programming': 'Software Development',
      'software': 'Software Development',
      'developer': 'Software Development',
      'coding': 'Software Development',
      'app': 'Apps & Tools',
      'tool': 'Apps & Tools',
      'gadget': 'Gadgets & Hardware',
      'hardware': 'Gadgets & Hardware',
      'cybersecurity': 'Cybersecurity',
      'security': 'Cybersecurity',
      'data': 'Data & Analytics',
      'analytics': 'Data & Analytics',
      'startup': 'Startups',
      'marketing': 'Marketing & Growth',
      'creator economy': 'Creator Economy',
      'investing': 'Investing',
      'investment': 'Investing',
      'crypto': 'Crypto',
      'economics': 'Finance',
      'budgeting': 'Personal Finance',
      'research': 'Science',
      'ai': 'AI & ML',
      'artificial intelligence': 'AI & ML',
      'machine learning': 'AI & ML',
      'llm': 'AI & ML',
      'space': 'Space & Astronomy',
      'astronomy': 'Space & Astronomy',
      'biology': 'Biology & Medicine',
      'medicine': 'Biology & Medicine',
      'fitness': 'Fitness',
      'nutrition': 'Nutrition',
      'mental health': 'Mental Health',
      'psychology': 'Mental Health',
      'learning': 'Education',
      'course': 'Education',
      'tutorial': 'Education',
      'language learning': 'Language Learning',
      'math': 'Math',
      'politics': 'Law & Policy',
      'world news': 'World Affairs',
      'history': 'History & Culture',
      'culture': 'History & Culture',
      'heritage': 'History & Culture',
      'mythology': 'History & Culture',
      'architecture': 'Architecture',
      'temple': 'Architecture',
      'spirituality': 'Spirituality & Philosophy',
      'spiritual': 'Spirituality & Philosophy',
      'philosophy': 'Spirituality & Philosophy',
      'religion': 'Spirituality & Philosophy',
      'bhagavad gita': 'Spirituality & Philosophy',
      'gita': 'Spirituality & Philosophy',
      'mahabharata': 'Spirituality & Philosophy',
      'career': 'Career',
      'job': 'Career',
      'productivity': 'Productivity',
      'relationship': 'Relationships',
      'dating': 'Relationships',
      'parenting': 'Parenting & Family',
      'family': 'Parenting & Family',
      'climate': 'Nature & Environment',
      'environment': 'Nature & Environment',
      'nature': 'Nature & Environment',
      'ux': 'Design',
      'ui': 'Design',
      'art': 'Art & Illustration',
      'illustration': 'Art & Illustration',
      'photography': 'Photography',
      'gardening': 'Home & Garden',
      'home': 'Home & Garden',
      'diy': 'DIY & Making',
      'making': 'DIY & Making',
      'food': 'Food & Cooking',
      'cooking': 'Food & Cooking',
      'restaurant': 'Restaurants & Cafes',
      'cafe': 'Restaurants & Cafes',
      'hiking': 'Outdoors & Adventure',
      'trekking': 'Outdoors & Adventure',
      'movies': 'Movies & TV',
      'tv': 'Movies & TV',
      'music': 'Music',
      'gaming': 'Gaming',
      'books': 'Books & Literature',
      'literature': 'Books & Literature',
      'documentation': 'Documentation',
      'self improvement': 'Lifestyle',
      'fashion': 'Fashion & Beauty',
      'beauty': 'Fashion & Beauty',
      'ecommerce': 'Shopping',
      'shopping': 'Shopping',
      'cars': 'Vehicles',
      'vehicles': 'Vehicles',
      'sports': 'Sports',
      'sport': 'Sports',
      'cricket': 'Sports',
      'football': 'Sports',
      'soccer': 'Sports',
      'basketball': 'Sports',
      'tennis': 'Sports',
      'athletics': 'Sports',
      'match': 'Sports',
      'tournament': 'Sports',
      'advaita': 'Spirituality & Philosophy',
      'vedanta': 'Spirituality & Philosophy',
      'advaita vedanta': 'Spirituality & Philosophy',
      'non-duality': 'Spirituality & Philosophy',
      'non duality': 'Spirituality & Philosophy',
      'non-dualism': 'Spirituality & Philosophy',
      'non dualism': 'Spirituality & Philosophy',
      'brahman': 'Spirituality & Philosophy',
      'consciousness': 'Spirituality & Philosophy',
    };

    if (synonymMap.containsKey(normalizedInput)) {
      return byName(synonymMap[normalizedInput]!);
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

    if (_hasFoodCookingSignal(searchable)) {
      add('Food & Cooking');
    }
    if (_containsAnyWord(searchable, [
      'health',
      'protein',
      'plant-based',
      'vegan',
      'calcium',
      'healthy',
    ])) {
      add('Health');
    }
    if (_containsAnyWord(searchable, [
      'ai',
      'artificial intelligence',
      'machine learning',
      'llm',
      'genai',
      'agent',
    ])) {
      add('AI & ML');
    }
    if (_containsAnyWord(searchable, [
      'react',
      'flutter',
      'dart',
      'javascript',
      'software',
      'code',
    ])) {
      add('Software Development');
    }
    if (_containsAnyWord(searchable, [
      'gadget',
      'hardware',
      'phone',
      'laptop',
      'camera',
      'headphones',
      'device',
    ])) {
      add('Gadgets & Hardware');
    }
    if (_containsAnyWord(searchable, [
      'app',
      'tool',
      'extension',
      'plugin',
      'automation',
    ])) {
      add('Apps & Tools');
    }
    if (_containsAnyWord(searchable, [
      'cybersecurity',
      'security',
      'privacy',
      'malware',
      'phishing',
      'vulnerability',
    ])) {
      add('Cybersecurity');
    }
    if (_containsAnyWord(searchable, [
      'data',
      'analytics',
      'dashboard',
      'sql',
      'database',
      'visualization',
    ])) {
      add('Data & Analytics');
    }
    if (_containsAnyWord(searchable, [
      'design',
      'figma',
      'typography',
      'ui',
      'ux',
    ])) {
      add('Design');
    }
    if (_containsAnyWord(searchable, [
      'architecture',
      'architectural',
      'temple',
      'monument',
      'heritage site',
      'historic structure',
    ])) {
      add('Architecture');
    }
    if (_containsAnyWord(searchable, [
      'history',
      'ancient',
      'culture',
      'cultural heritage',
      'civilization',
      'mythology',
      'mahabharata',
      'ramayana',
    ])) {
      add('History & Culture');
    }
    if (_containsAnyWord(searchable, [
      'spiritual',
      'spirituality',
      'philosophy',
      'bhagavad gita',
      'gita',
      'krishna',
      'arjuna',
      'dharma',
      'vedic',
      'meditation',
    ])) {
      add('Spirituality & Philosophy');
    }
    if (_containsAnyWord(searchable, [
      'relationship',
      'dating',
      'marriage',
      'friendship',
      'communication',
    ])) {
      add('Relationships');
    }
    if (_containsAnyWord(searchable, [
      'career',
      'job',
      'interview',
      'resume',
      'workplace',
      'promotion',
    ])) {
      add('Career');
    }
    if (_containsAnyWord(searchable, [
      'productivity',
      'habit',
      'workflow',
      'focus',
      'time management',
    ])) {
      add('Productivity');
    }
    if (_containsAnyWord(searchable, [
      'climate',
      'environment',
      'wildlife',
      'nature',
      'sustainability',
    ])) {
      add('Nature & Environment');
    }
    if (_containsAnyWord(searchable, [
      'parenting',
      'family',
      'kids',
      'children',
      'childcare',
    ])) {
      add('Parenting & Family');
    }
    if (_containsAnyWord(searchable, [
      'startup',
      'founder',
      'fundraising',
      'venture capital',
      'pitch deck',
    ])) {
      add('Startups');
    }
    if (_containsAnyWord(searchable, [
      'marketing',
      'growth',
      'seo',
      'copywriting',
      'sales',
    ])) {
      add('Marketing & Growth');
    }
    if (_containsAnyWord(searchable, [
      'creator',
      'audience',
      'monetization',
      'newsletter',
      'youtube growth',
    ])) {
      add('Creator Economy');
    }
    if (_containsAnyWord(searchable, [
      'budget',
      'personal finance',
      'credit card',
      'tax',
      'saving money',
    ])) {
      add('Personal Finance');
    }
    if (_containsAnyWord(searchable, [
      'invest',
      'stock',
      'portfolio',
      'market',
      'etf',
    ])) {
      add('Investing');
    }
    if (_containsAnyWord(searchable, [
      'crypto',
      'bitcoin',
      'ethereum',
      'web3',
      'defi',
    ])) {
      add('Crypto');
    }
    if (_containsAnyWord(searchable, [
      'space',
      'astronomy',
      'nasa',
      'planet',
      'galaxy',
    ])) {
      add('Space & Astronomy');
    }
    if (_containsAnyWord(searchable, [
      'biology',
      'medicine',
      'medical',
      'genetics',
      'neuroscience',
    ])) {
      add('Biology & Medicine');
    }
    if (_containsAnyWord(searchable, [
      'fitness',
      'workout',
      'strength',
      'running',
      'exercise',
    ])) {
      add('Fitness');
    }
    if (_containsAnyWord(searchable, [
      'nutrition',
      'diet',
      'protein',
      'calorie',
      'vitamin',
    ])) {
      add('Nutrition');
    }
    if (_containsAnyWord(searchable, [
      'mental health',
      'psychology',
      'therapy',
      'anxiety',
      'mindfulness',
    ])) {
      add('Mental Health');
    }
    if (_containsAnyWord(searchable, [
      'language learning',
      'vocabulary',
      'grammar',
      'english',
      'japanese',
    ])) {
      add('Language Learning');
    }
    if (_containsAnyWord(searchable, [
      'math',
      'algebra',
      'calculus',
      'statistics',
    ])) {
      add('Math');
    }
    if (_containsAnyWord(searchable, [
      'world affairs',
      'geopolitics',
      'international relations',
      'foreign policy',
    ])) {
      add('World Affairs');
    }
    if (_containsAnyWord(searchable, [
      'law',
      'policy',
      'legal',
      'regulation',
      'government',
    ])) {
      add('Law & Policy');
    }
    if (_containsAnyWord(searchable, [
      'art',
      'illustration',
      'drawing',
      'painting',
    ])) {
      add('Art & Illustration');
    }
    if (_containsAnyWord(searchable, [
      'photo',
      'photography',
      'camera',
      'portrait',
    ])) {
      add('Photography');
    }
    if (_containsAnyWord(searchable, [
      'diy',
      'maker',
      'woodworking',
      'repair',
      'craft',
    ])) {
      add('DIY & Making');
    }
    if (_containsAnyWord(searchable, [
      'restaurant',
      'cafe',
      'coffee shop',
      'dining',
    ])) {
      add('Restaurants & Cafes');
    }
    if (_containsAnyWord(searchable, [
      'travel',
      'trek',
      'hike',
      'destination',
      'route',
    ])) {
      add('Travel');
    }
    if (_containsAnyWord(searchable, [
      'hike',
      'hiking',
      'trek',
      'camping',
      'trail',
      'outdoors',
    ])) {
      add('Outdoors & Adventure');
    }
    if (_containsAnyWord(searchable, [
      'movie',
      'film',
      'cinema',
      'tv show',
      'series',
      'anime',
    ])) {
      add('Movies & TV');
    }
    if (_containsAnyWord(searchable, ['music', 'song', 'album', 'playlist'])) {
      add('Music');
    }
    if (_containsAnyWord(searchable, [
      'gaming',
      'game',
      'videogame',
      'steam',
    ])) {
      add('Gaming');
    }
    if (_containsAnyWord(searchable, [
      'fashion',
      'style',
      'outfit',
      'skincare',
      'beauty',
    ])) {
      add('Fashion & Beauty');
    }
    if (_containsAnyWord(searchable, [
      'car',
      'bike',
      'vehicle',
      'ev',
      'motorcycle',
    ])) {
      add('Vehicles');
    }
    if (_containsAnyWord(searchable, [
      'book',
      'novel',
      'author',
      'literature',
      'poetry',
    ])) {
      add('Books & Literature');
    }
    if (_containsAnyWord(searchable, [
      'documentation',
      'docs',
      'manual',
      'api reference',
    ])) {
      add('Documentation');
    }

    return inferred;
  }

  static List<String> curateSourceCategories({
    required List<String> categories,
    required List<String> tags,
    required String text,
    String? primaryCategory,
    int maxSources = 3,
  }) {
    final ordered = <String>[];
    final searchableText = text.toLowerCase();
    final searchableTags = tags.join(' ').toLowerCase();

    void add(String category) {
      final trimmed = category.trim();
      if (trimmed.isEmpty || trimmed == 'Web' || trimmed == 'Other') return;
      if (tryByName(trimmed) == null) return;
      if (!ordered.contains(trimmed)) ordered.add(trimmed);
    }

    final primary = primaryCategory?.trim();
    if (primary != null && primary.isNotEmpty) {
      add(primary);
    }

    for (final category in categories) {
      final trimmed = category.trim();
      if (trimmed.isEmpty || trimmed == primary) continue;
      if (_hasSourceEvidence(
        trimmed,
        text: searchableText,
        tags: searchableTags,
      )) {
        add(trimmed);
      }
      if (ordered.length >= maxSources) break;
    }

    if (ordered.isEmpty) {
      final inferred = inferAdditionalCategories(tags: tags, text: text);
      for (final category in inferred) {
        add(category);
        if (ordered.length >= maxSources) break;
      }
    }

    return ordered.isEmpty ? ['Other'] : ordered.take(maxSources).toList();
  }

  static List<String> sourceHierarchyLabels({
    required List<String> categories,
    required List<String> tags,
    required String text,
    String? primaryCategory,
    int maxSources = 3,
  }) {
    final curated = curateSourceCategories(
      categories: categories,
      tags: tags,
      text: text,
      primaryCategory: primaryCategory,
      maxSources: maxSources,
    );
    final leaf = curated.firstWhere(
      (category) => category != 'Other',
      orElse: () => '',
    );
    if (leaf.isEmpty) return ['Other'];

    final labels = <String>[];
    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || labels.contains(trimmed)) return;
      labels.add(trimmed);
    }

    for (final label in _sourceLineageFor(
      leaf,
      categories: curated,
      text: text,
    )) {
      add(label);
      if (labels.length >= maxSources) return labels;
    }

    for (final category in curated.skip(1)) {
      if (labels.length >= maxSources) break;
      if (_isSiblingOrParentNoise(labels, category)) continue;
      add(category);
    }

    final niche = _strongNicheTag(
      tags: tags,
      text: text,
      selectedLabels: labels,
    );
    if (niche != null && labels.length < maxSources) {
      add(niche);
    }

    return labels.isEmpty ? ['Other'] : labels;
  }

  static List<String> _sourceLineage(String category) {
    return switch (category) {
      'AI & ML' ||
      'Software Development' ||
      'Gadgets & Hardware' ||
      'Apps & Tools' ||
      'Cybersecurity' ||
      'Data & Analytics' => ['Technology', category],
      'Startups' ||
      'Marketing & Growth' ||
      'Creator Economy' => ['Business', category],
      'Personal Finance' || 'Investing' || 'Crypto' => ['Finance', category],
      'Space & Astronomy' || 'Biology & Medicine' => ['Science', category],
      'Fitness' || 'Nutrition' || 'Mental Health' => ['Health', category],
      'Language Learning' || 'Math' => ['Education', category],
      'World Affairs' || 'Law & Policy' => ['News', category],
      'Art & Illustration' || 'Photography' => ['Design', category],
      'DIY & Making' || 'Restaurants & Cafes' => ['Lifestyle', category],
      'Outdoors & Adventure' => ['Travel', category],
      'Movies & TV' || 'Gaming' => ['Entertainment', category],
      'Fashion & Beauty' || 'Vehicles' => ['Lifestyle', category],
      'Books & Literature' || 'Documentation' => ['Reference', category],
      _ => [category],
    };
  }

  static List<String> _sourceLineageFor(
    String category, {
    required List<String> categories,
    required String text,
  }) {
    final evidence = text.toLowerCase();
    final hasHistorySignal =
        categories.contains('History & Culture') ||
        _containsAnyWord(evidence, const [
          'history',
          'ancient',
          'culture',
          'cultural',
          'heritage',
          'civilization',
          'temple',
          'monument',
        ]);
    if (category == 'Architecture' && hasHistorySignal) {
      return ['History & Culture', 'Architecture'];
    }
    if (category == 'History & Culture' &&
        _containsAnyWord(evidence, const [
          'architecture',
          'architectural',
          'temple',
          'monument',
          'built heritage',
        ])) {
      return ['History & Culture', 'Architecture'];
    }
    return _sourceLineage(category);
  }

  static bool _isSiblingOrParentNoise(List<String> selected, String category) {
    final lineage = _sourceLineage(category);
    return lineage.any(selected.contains);
  }

  static String? _strongNicheTag({
    required List<String> tags,
    required String text,
    required List<String> selectedLabels,
  }) {
    final selected = selectedLabels.map((item) => item.toLowerCase()).toSet();
    final evidence = '$text ${tags.join(' ')}'.toLowerCase();
    final candidates = <String>[];
    for (final tag in tags) {
      final cleaned = _cleanNicheTag(tag);
      if (cleaned == null || selected.contains(cleaned.toLowerCase())) {
        continue;
      }
      if (_containsAnyWord(evidence, [cleaned.toLowerCase()])) {
        candidates.add(cleaned);
      }
    }
    candidates.sort((a, b) => a.length.compareTo(b.length));
    return candidates.isEmpty ? null : candidates.first;
  }

  static String? _cleanNicheTag(String tag) {
    final cleaned = tag.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length < 3 || cleaned.length > 28) return null;
    if (_nicheTagStoplist.contains(cleaned)) return null;
    if (tryByName(_titleCase(cleaned)) != null) return null;
    if (!RegExp(r'^[a-z0-9][a-z0-9 &+\-]*$').hasMatch(cleaned)) return null;
    return _titleCase(cleaned);
  }

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length <= 3 && RegExp(r'^[a-z0-9]+$').hasMatch(part)) {
            return part.toUpperCase();
          }
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  /// Word-aware match: the needle must be a whole word/phrase. This keeps short
  /// needles like "car" from matching "career", while still allowing explicit
  /// variants such as "cook" and "cooking" to be listed separately.
  static bool _containsAnyWord(String text, List<String> needles) {
    for (final needle in needles) {
      final escaped = RegExp.escape(needle).replaceAll(r'\ ', r'\s+');
      if (RegExp('(?<![a-z0-9])$escaped(?![a-z0-9])').hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasSourceEvidence(
    String category, {
    required String text,
    required String tags,
  }) {
    final evidence = '$text $tags';
    switch (category) {
      case 'Food & Cooking':
        return _hasFoodCookingSignal(evidence);
      case 'Vehicles':
        return _containsAnyWord(evidence, const [
          'car',
          'cars',
          'bike',
          'bikes',
          'vehicle',
          'vehicles',
          'ev',
          'motorcycle',
          'motorcycles',
          'automotive',
        ]);
      case 'Marketing & Growth':
        return _containsAnyWord(evidence, const [
          'marketing',
          'seo',
          'copywriting',
          'sales funnel',
          'brand strategy',
          'customer acquisition',
          'growth marketing',
        ]);
      case 'Parenting & Family':
        return _containsAnyWord(evidence, const [
          'parenting',
          'parenthood',
          'parents',
          'family dynamics',
          'childcare',
          'kids',
          'children',
        ]);
      case 'Reference':
        return _containsAnyWord(evidence, const [
          'reference',
          'guide',
          'manual',
          'documentation',
          'docs',
        ]);
      case 'Technology':
        return _containsAnyWord(evidence, const [
          'technology',
          'software',
          'developer',
          'programming',
          'code',
          'coding',
          'api',
          'ai',
          'llm',
        ]);
      case 'Entertainment':
        return _containsAnyWord(evidence, const [
          'entertainment',
          'movie',
          'movies',
          'film',
          'series',
          'anime',
          'show',
          'watch',
        ]);
      case 'Lifestyle':
        return _containsAnyWord(evidence, const [
          'lifestyle',
          'self improvement',
          'personal growth',
          'habits',
        ]);
      default:
        return _categoryEvidenceNeedles(
          category,
        ).any((needle) => _containsAnyWord(evidence, [needle]));
    }
  }

  static List<String> _categoryEvidenceNeedles(String category) {
    return switch (category) {
      'AI & ML' => const [
        'ai',
        'artificial intelligence',
        'machine learning',
        'llm',
        'genai',
      ],
      'Software Development' => const [
        'react',
        'flutter',
        'dart',
        'javascript',
        'typescript',
        'software',
        'code',
        'api',
      ],
      'Gadgets & Hardware' => const [
        'gadget',
        'hardware',
        'phone',
        'laptop',
        'camera',
        'headphones',
        'device',
      ],
      'Apps & Tools' => const ['app', 'tool', 'extension', 'plugin'],
      'Cybersecurity' => const [
        'cybersecurity',
        'privacy',
        'malware',
        'phishing',
        'vulnerability',
      ],
      'Data & Analytics' => const [
        'data',
        'analytics',
        'dashboard',
        'sql',
        'database',
        'visualization',
      ],
      'Architecture' => const [
        'architecture',
        'architectural',
        'temple',
        'monument',
        'heritage site',
      ],
      'History & Culture' => const [
        'history',
        'ancient',
        'culture',
        'cultural heritage',
        'civilization',
        'mythology',
      ],
      'Spirituality & Philosophy' => const [
        'spirituality',
        'philosophy',
        'bhagavad gita',
        'gita',
        'krishna',
        'arjuna',
        'dharma',
        'meditation',
      ],
      'Movies & TV' => const [
        'movie',
        'movies',
        'film',
        'cinema',
        'tv show',
        'series',
        'anime',
      ],
      'Books & Literature' => const [
        'book',
        'books',
        'novel',
        'author',
        'literature',
        'poetry',
        'reading',
      ],
      'Travel' => const ['travel', 'trip', 'destination', 'itinerary'],
      'Outdoors & Adventure' => const [
        'hike',
        'hiking',
        'trek',
        'camping',
        'trail',
        'outdoors',
      ],
      'Education' => const ['learn', 'study', 'course', 'lesson', 'tutorial'],
      'Health' => const ['health', 'sleep', 'medicine', 'healthy'],
      'Fitness' => const ['fitness', 'workout', 'strength', 'running'],
      'Nutrition' => const ['nutrition', 'diet', 'calorie', 'vitamin'],
      'Mental Health' => const ['mental health', 'therapy', 'anxiety'],
      'Career' => const ['career', 'job', 'interview', 'resume', 'workplace'],
      'Productivity' => const ['productivity', 'habit', 'workflow', 'focus'],
      'Relationships' => const [
        'relationship',
        'dating',
        'marriage',
        'friendship',
      ],
      'Startups' => const ['startup', 'founder', 'fundraising'],
      'Creator Economy' => const ['creator', 'audience', 'monetization'],
      'Personal Finance' => const ['budget', 'credit card', 'tax'],
      'Investing' => const ['investing', 'stock', 'portfolio', 'etf'],
      'Crypto' => const ['crypto', 'bitcoin', 'ethereum', 'web3'],
      'Music' => const ['music', 'song', 'album', 'playlist'],
      'Gaming' => const ['gaming', 'game', 'videogame'],
      'Fashion & Beauty' => const ['fashion', 'style', 'outfit', 'skincare'],
      'Documentation' => const ['documentation', 'docs', 'manual'],
      _ => const [],
    };
  }

  static bool _hasFoodCookingSignal(String text) {
    final searchable = text.toLowerCase();
    final foodWithoutRecipe = searchable.replaceAll(
      RegExp(r'\brecipes?\b'),
      ' ',
    );
    if (_containsAnyWord(foodWithoutRecipe, _strongFoodCookingNeedles)) {
      return true;
    }
    if (!RegExp(r'(?<![a-z0-9])recipes?\b').hasMatch(searchable)) {
      return false;
    }
    if (_hasMetaphoricalRecipeUse(searchable)) {
      return false;
    }
    return _containsAnyWord(searchable, _recipeContextNeedles) ||
        RegExp(
          r'\b(?:ingredients?|servings?|prep|dish|meal)\b.{0,60}\brecipes?\b|\brecipes?\b.{0,60}\b(?:ingredients?|servings?|prep|dish|meal|for\s+(?:breakfast|lunch|dinner))\b',
        ).hasMatch(searchable);
  }

  static bool _hasMetaphoricalRecipeUse(String text) {
    return RegExp(
          r'\brecipes?\s+(?:for|to)\s+(?:success|failure|happiness|life|business|growth|winning|wealth|productivity)\b',
        ).hasMatch(text) ||
        RegExp(
          r'\b(?:success|failure|happiness|life|business|growth|winning|wealth|productivity)\b.{0,48}\brecipes?\b',
        ).hasMatch(text) ||
        RegExp(
          r'\b(?:doesn['
          '’]?t|does not|do not|don['
          '’]?t|never|no)\b.{0,48}\brecipes?\b',
        ).hasMatch(text);
  }

  static const _strongFoodCookingNeedles = <String>[
    'kitchen',
    'cook',
    'cooking',
    'bake',
    'baking',
    'meal prep',
    'mealprep',
    'food',
    'food hack',
    'ingredient',
    'ingredients',
    'dessert',
    'smoothie',
    'paneer',
    'pasta',
    'ramen',
    'chicken',
    'sauce',
    'curry',
    'rice',
    'noodles',
    'breakfast',
    'lunch',
    'dinner',
    'snack',
    'coffee',
    'dish',
    'cuisine',
  ];

  static const _recipeContextNeedles = <String>[
    'kitchen',
    'cook',
    'cooking',
    'bake',
    'baking',
    'ingredient',
    'ingredients',
    'serving',
    'servings',
    'dish',
    'meal',
    'dessert',
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  static const _nicheTagStoplist = <String>{
    'instagram',
    'youtube',
    'video',
    'reel',
    'post',
    'thread',
    'article',
    'content',
    'recommendation',
    'recommendations',
    'tips',
    'guide',
    'learn',
    'watch',
    'read',
    'saved',
    'social',
    'web',
    'other',
  };

  static CategoryDefinition byName(String name) {
    return tryByName(name) ?? const CategoryDefinition('Other', '🔖');
  }

  static CategoryDefinition? tryByName(String name) {
    final canonical = _interestAliases[name.trim().toLowerCase()];
    for (final item in categories) {
      if (item.name == name || item.name == canonical) {
        return item;
      }
    }
    return null;
  }
}
