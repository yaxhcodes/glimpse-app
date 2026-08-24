import 'package:flutter/material.dart';

import '../../core/models/user_collection.dart';

enum CollectionVisualStyle {
  travel(
    'travel',
    'Travel',
    Icons.flight_takeoff_rounded,
  ),
  places(
    'places',
    'Places',
    Icons.travel_explore_outlined,
  ),
  outdoors(
    'outdoors',
    'Outdoors',
    Icons.terrain_outlined,
  ),
  systems(
    'systems',
    'Systems',
    Icons.hub_outlined,
  ),
  research(
    'research',
    'Research',
    Icons.menu_book_rounded,
  ),
  development(
    'development',
    'Code',
    Icons.code_rounded,
  ),
  design(
    'design',
    'Design',
    Icons.palette_outlined,
  ),
  knowledge(
    'knowledge',
    'Ideas',
    Icons.psychology_alt_outlined,
  ),
  launch(
    'launch',
    'Launch',
    Icons.rocket_launch_outlined,
  ),
  finance(
    'finance',
    'Finance',
    Icons.account_balance_wallet_outlined,
  ),
  health(
    'health',
    'Health',
    Icons.favorite_border_rounded,
  ),
  food(
    'food',
    'Food',
    Icons.restaurant_rounded,
  ),
  music(
    'music',
    'Music',
    Icons.headphones_rounded,
  ),
  media(
    'media',
    'Media',
    Icons.movie_creation_outlined,
  ),
  shopping(
    'shopping',
    'Shopping',
    Icons.shopping_bag_outlined,
  ),
  work(
    'work',
    'Work',
    Icons.work_outline_rounded,
  ),
  learning(
    'learning',
    'Learning',
    Icons.school_outlined,
  ),
  science(
    'science',
    'Science',
    Icons.science_outlined,
  ),
  news(
    'news',
    'Articles',
    Icons.article_outlined,
  ),
  people(
    'people',
    'People',
    Icons.groups_outlined,
  ),
  sports(
    'sports',
    'Sports',
    Icons.sports_soccer_outlined,
  ),
  gaming(
    'gaming',
    'Gaming',
    Icons.sports_esports_outlined,
  ),
  security(
    'security',
    'Security',
    Icons.shield_outlined,
  ),
  legal(
    'legal',
    'Legal',
    Icons.gavel_outlined,
  ),
  productivity(
    'productivity',
    'Productivity',
    Icons.checklist_rounded,
  ),
  home(
    'home',
    'Home',
    Icons.home_work_outlined,
  ),
  fallback(
    'space',
    'General',
    Icons.topic_outlined,
  );

  const CollectionVisualStyle(
    this.key,
    this.label,
    this.icon,
  );

  final String key;
  final String label;
  final IconData icon;
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

    return Semantics(
      label: semanticLabel ?? style.label,
      image: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: selected ? Border.all(color: cs.primary, width: 1.1) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.12),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          style.icon,
          size: iconSize,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}
