import 'package:flutter/material.dart';

import '../../core/models/user_collection.dart';

enum CollectionVisualStyle {
  travel(
    'travel',
    'Travel',
    Icons.flight_takeoff_rounded,
    Color(0xFF85C7B7),
  ),
  places(
    'places',
    'Places',
    Icons.travel_explore_outlined,
    Color(0xFF8FC6D6),
  ),
  outdoors(
    'outdoors',
    'Outdoors',
    Icons.terrain_outlined,
    Color(0xFF9BCB8D),
  ),
  systems(
    'systems',
    'Systems',
    Icons.hub_outlined,
    Color(0xFF9FA8DA),
  ),
  research(
    'research',
    'Research',
    Icons.menu_book_rounded,
    Color(0xFFD7BA7D),
  ),
  development(
    'development',
    'Code',
    Icons.code_rounded,
    Color(0xFF80CBC4),
  ),
  design(
    'design',
    'Design',
    Icons.palette_outlined,
    Color(0xFFE7A6B8),
  ),
  knowledge(
    'knowledge',
    'Ideas',
    Icons.psychology_alt_outlined,
    Color(0xFFC3B5FD),
  ),
  launch(
    'launch',
    'Launch',
    Icons.rocket_launch_outlined,
    Color(0xFFE8C07D),
  ),
  finance(
    'finance',
    'Finance',
    Icons.account_balance_wallet_outlined,
    Color(0xFFA8D08D),
  ),
  health(
    'health',
    'Health',
    Icons.favorite_border_rounded,
    Color(0xFFE5A0A8),
  ),
  food(
    'food',
    'Food',
    Icons.restaurant_rounded,
    Color(0xFFD9B06F),
  ),
  music(
    'music',
    'Music',
    Icons.headphones_rounded,
    Color(0xFFB5A7E6),
  ),
  media(
    'media',
    'Media',
    Icons.movie_creation_outlined,
    Color(0xFF8DB8E8),
  ),
  shopping(
    'shopping',
    'Shopping',
    Icons.shopping_bag_outlined,
    Color(0xFFD6A786),
  ),
  work(
    'work',
    'Work',
    Icons.work_outline_rounded,
    Color(0xFFB7C2D8),
  ),
  learning(
    'learning',
    'Learning',
    Icons.school_outlined,
    Color(0xFFCFBE84),
  ),
  science(
    'science',
    'Science',
    Icons.science_outlined,
    Color(0xFF92CEC8),
  ),
  news(
    'news',
    'Articles',
    Icons.article_outlined,
    Color(0xFFB4C3D8),
  ),
  people(
    'people',
    'People',
    Icons.groups_outlined,
    Color(0xFFD4A6C8),
  ),
  sports(
    'sports',
    'Sports',
    Icons.sports_soccer_outlined,
    Color(0xFFAED28F),
  ),
  gaming(
    'gaming',
    'Gaming',
    Icons.sports_esports_outlined,
    Color(0xFFB9A3E6),
  ),
  security(
    'security',
    'Security',
    Icons.shield_outlined,
    Color(0xFF8FBED6),
  ),
  legal(
    'legal',
    'Legal',
    Icons.gavel_outlined,
    Color(0xFFD1B07E),
  ),
  productivity(
    'productivity',
    'Productivity',
    Icons.checklist_rounded,
    Color(0xFF9FC8BC),
  ),
  home(
    'home',
    'Home',
    Icons.home_work_outlined,
    Color(0xFFAFC8A6),
  ),
  fallback(
    'space',
    'General',
    Icons.topic_outlined,
    Color(0xFFBFC7D5),
  );

  const CollectionVisualStyle(
    this.key,
    this.label,
    this.icon,
    this.accent,
  );

  final String key;
  final String label;
  final IconData icon;
  final Color accent;
}

const collectionVisualOptions = <CollectionVisualStyle>[
  CollectionVisualStyle.travel,
  CollectionVisualStyle.places,
  CollectionVisualStyle.outdoors,
  CollectionVisualStyle.systems,
  CollectionVisualStyle.research,
  CollectionVisualStyle.development,
  CollectionVisualStyle.design,
  CollectionVisualStyle.knowledge,
  CollectionVisualStyle.launch,
  CollectionVisualStyle.finance,
  CollectionVisualStyle.health,
  CollectionVisualStyle.food,
  CollectionVisualStyle.music,
  CollectionVisualStyle.media,
  CollectionVisualStyle.shopping,
  CollectionVisualStyle.work,
  CollectionVisualStyle.learning,
  CollectionVisualStyle.science,
  CollectionVisualStyle.news,
  CollectionVisualStyle.people,
  CollectionVisualStyle.sports,
  CollectionVisualStyle.gaming,
  CollectionVisualStyle.security,
  CollectionVisualStyle.legal,
  CollectionVisualStyle.productivity,
  CollectionVisualStyle.home,
  CollectionVisualStyle.fallback,
];

CollectionVisualStyle resolveCollectionVisual(UserCollection collection) {
  return resolveCollectionVisualStyle(
    collection.emoji,
    name: collection.name,
    description: collection.description,
  );
}

CollectionVisualStyle resolveCollectionVisualStyle(
  String? key, {
  String? name,
  String? description,
}) {
  final normalizedKey = key?.trim().toLowerCase();
  for (final option in CollectionVisualStyle.values) {
    if (option.key == normalizedKey) return option;
  }

  final title = _normalizeVisualText(name);
  final supporting = _normalizeVisualText(description);
  final scores = <CollectionVisualStyle, int>{};

  for (final entry in _visualKeywords.entries) {
    final style = entry.key;
    for (final keyword in entry.value) {
      if (_containsKeyword(title, keyword)) {
        scores[style] = (scores[style] ?? 0) + 4;
      }
      if (_containsKeyword(supporting, keyword)) {
        scores[style] = (scores[style] ?? 0) + 1;
      }
    }
  }

  for (final place in _placeKeywords) {
    if (_containsKeyword(title, place)) {
      scores[CollectionVisualStyle.places] =
          (scores[CollectionVisualStyle.places] ?? 0) + 3;
    }
    if (_containsKeyword(supporting, place)) {
      scores[CollectionVisualStyle.places] =
          (scores[CollectionVisualStyle.places] ?? 0) + 1;
    }
  }

  if (scores.isEmpty) return CollectionVisualStyle.fallback;
  final sorted = scores.entries.toList()
    ..sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) return scoreCompare;
      return CollectionVisualStyle.values
          .indexOf(a.key)
          .compareTo(CollectionVisualStyle.values.indexOf(b.key));
    });
  return sorted.first.key;
}

const _visualKeywords = <CollectionVisualStyle, List<String>>{
  CollectionVisualStyle.outdoors: [
    'hike',
    'hikes',
    'hiking',
    'trail',
    'trails',
    'trek',
    'trekking',
    'mountain',
    'mountains',
    'outdoor',
    'outdoors',
    'camp',
    'camping',
    'nature',
    'forest',
    'park',
    'parks',
    'backpack',
    'climb',
    'climbing',
  ],
  CollectionVisualStyle.travel: [
    'travel',
    'trip',
    'trips',
    'wander',
    'flight',
    'flights',
    'journey',
    'city',
    'cities',
    'hotel',
    'hotels',
    'places',
    'vacation',
    'visa',
    'itinerary',
    'roadtrip',
  ],
  CollectionVisualStyle.places: [
    'place',
    'places',
    'city',
    'cities',
    'country',
    'countries',
    'state',
    'states',
    'region',
    'regions',
    'neighbourhood',
    'neighborhood',
    'local',
    'maps',
    'map',
    'guide',
    'guides',
  ],
  CollectionVisualStyle.systems: [
    'system',
    'systems',
    'scale',
    'network',
    'architecture',
    'infrastructure',
    'backend',
    'distributed',
  ],
  CollectionVisualStyle.research: [
    'read',
    'reading',
    'research',
    'book',
    'books',
    'paper',
    'papers',
    'study',
  ],
  CollectionVisualStyle.development: [
    'code',
    'coding',
    'dev',
    'development',
    'engineering',
    'flutter',
    'react',
    'reactjs',
    'vue',
    'angular',
    'svelte',
    'swift',
    'swiftui',
    'kotlin',
    'python',
    'javascript',
    'typescript',
    'rust',
    'go',
    'golang',
    'firebase',
    'supabase',
    'docker',
    'kubernetes',
    'github',
    'git',
    'api',
    'programming',
    'software',
  ],
  CollectionVisualStyle.design: [
    'design',
    'brand',
    'visual',
    'ui',
    'ux',
    'palette',
    'inspiration',
  ],
  CollectionVisualStyle.knowledge: [
    'idea',
    'ideas',
    'ai',
    'llm',
    'gpt',
    'model',
    'models',
    'machine learning',
    'ml',
    'prompt',
    'prompts',
    'knowledge',
    'thinking',
    'notes',
    'mind',
  ],
  CollectionVisualStyle.launch: [
    'launch',
    'startup',
    'growth',
    'product',
  ],
  CollectionVisualStyle.finance: [
    'money',
    'finance',
    'invest',
    'investment',
    'budget',
    'tax',
    'crypto',
    'bank',
  ],
  CollectionVisualStyle.health: [
    'health',
    'wellness',
    'medical',
    'doctor',
    'therapy',
    'mental',
    'fitness',
  ],
  CollectionVisualStyle.food: [
    'food',
    'recipe',
    'cook',
    'restaurant',
    'coffee',
    'dining',
  ],
  CollectionVisualStyle.music: [
    'music',
    'album',
    'playlist',
    'audio',
    'song',
    'sound',
  ],
  CollectionVisualStyle.media: [
    'movie',
    'film',
    'video',
    'youtube',
    'watch',
    'cinema',
  ],
  CollectionVisualStyle.shopping: [
    'shop',
    'shopping',
    'buy',
    'wishlist',
    'gear',
  ],
  CollectionVisualStyle.work: [
    'work',
    'career',
    'job',
    'office',
    'client',
    'project',
  ],
  CollectionVisualStyle.learning: [
    'learn',
    'learning',
    'course',
    'class',
    'lesson',
    'tutorial',
    'education',
  ],
  CollectionVisualStyle.science: [
    'science',
    'biology',
    'physics',
    'chemistry',
    'space',
    'experiment',
  ],
  CollectionVisualStyle.sports: [
    'sport',
    'sports',
    'football',
    'soccer',
    'cricket',
    'tennis',
    'basketball',
    'nba',
    'f1',
    'formula',
    'running',
    'marathon',
    'cycling',
    'yoga',
  ],
  CollectionVisualStyle.gaming: [
    'game',
    'games',
    'gaming',
    'steam',
    'playstation',
    'xbox',
    'nintendo',
    'esports',
    'minecraft',
    'valorant',
  ],
  CollectionVisualStyle.security: [
    'security',
    'privacy',
    'password',
    'passwords',
    'auth',
    'authentication',
    'encryption',
    'malware',
    'threat',
    'vulnerability',
  ],
  CollectionVisualStyle.legal: [
    'legal',
    'law',
    'contract',
    'contracts',
    'policy',
    'policies',
    'compliance',
    'rights',
    'license',
  ],
  CollectionVisualStyle.productivity: [
    'todo',
    'notion',
    'obsidian',
    'calendar',
    'meeting',
    'meetings',
    'template',
    'templates',
    'task',
    'tasks',
    'productivity',
    'workflow',
    'workflows',
    'habit',
    'habits',
    'routine',
    'routines',
    'planning',
    'plan',
  ],
  CollectionVisualStyle.news: [
    'news',
    'article',
    'articles',
    'essay',
    'blog',
    'writing',
    'journalism',
  ],
  CollectionVisualStyle.people: [
    'people',
    'team',
    'community',
    'family',
    'friends',
    'social',
  ],
  CollectionVisualStyle.home: [
    'home',
    'house',
    'garden',
    'interior',
    'apartment',
    'decor',
  ],
};

const _placeKeywords = <String>[
  // India and nearby common user cases.
  'india',
  'mumbai',
  'bombay',
  'delhi',
  'new delhi',
  'bangalore',
  'bengaluru',
  'hyderabad',
  'pune',
  'chennai',
  'kolkata',
  'goa',
  'jaipur',
  'ahmedabad',
  'surat',
  'kerala',
  'ladakh',
  'kashmir',
  'himachal',
  'uttarakhand',
  'rajasthan',
  'sikkim',
  'nepal',
  'bhutan',
  'sri lanka',
  'maldives',
  'dubai',
  'singapore',
  'bali',

  // Countries and regions people commonly save trips/research around.
  'japan',
  'korea',
  'south korea',
  'china',
  'thailand',
  'vietnam',
  'indonesia',
  'malaysia',
  'turkey',
  'italy',
  'france',
  'spain',
  'portugal',
  'germany',
  'netherlands',
  'switzerland',
  'austria',
  'greece',
  'iceland',
  'norway',
  'sweden',
  'finland',
  'uk',
  'england',
  'scotland',
  'ireland',
  'usa',
  'america',
  'canada',
  'mexico',
  'brazil',
  'argentina',
  'australia',
  'new zealand',
  'egypt',
  'morocco',
  'kenya',
  'south africa',

  // Major city names.
  'tokyo',
  'kyoto',
  'seoul',
  'bangkok',
  'hanoi',
  'ho chi minh',
  'jakarta',
  'kuala lumpur',
  'istanbul',
  'london',
  'paris',
  'rome',
  'milan',
  'venice',
  'barcelona',
  'madrid',
  'lisbon',
  'berlin',
  'amsterdam',
  'zurich',
  'vienna',
  'athens',
  'reykjavik',
  'oslo',
  'stockholm',
  'helsinki',
  'new york',
  'nyc',
  'san francisco',
  'los angeles',
  'la',
  'chicago',
  'toronto',
  'vancouver',
  'sydney',
  'melbourne',
  'auckland',
  'queenstown',
  'cairo',
  'cape town',
];

String _normalizeVisualText(String? value) {
  return ' ${(value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
}

bool _containsKeyword(String value, String keyword) {
  final normalized = keyword.toLowerCase();
  if (value.contains(' $normalized ')) return true;
  if (normalized.length > 3 && value.contains(' ${normalized}s ')) return true;
  if (normalized.length > 3 && value.contains(' ${normalized}es ')) {
    return true;
  }
  return false;
}

class CollectionVisual extends StatelessWidget {
  const CollectionVisual({
    super.key,
    required this.style,
    this.size = 48,
    this.iconSize = 22,
    this.selected = false,
    this.semanticLabel,
    this.seed,
  });

  final CollectionVisualStyle style;
  final double size;
  final double iconSize;
  final bool selected;
  final String? semanticLabel;
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = style.accent;

    return Semantics(
      label: semanticLabel ?? style.label,
      image: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: selected ? 0.16 : 0.08),
            cs.surfaceContainerHigh,
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.46)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.1 : 0.8,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          style.icon,
          size: iconSize,
          color: accent.withValues(alpha: selected ? 0.95 : 0.86),
        ),
      ),
    );
  }
}
