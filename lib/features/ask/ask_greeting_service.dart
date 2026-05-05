import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Persistence abstraction
// ---------------------------------------------------------------------------

abstract class GreetingStore {
  Future<DateTime?> lastTime();
  Future<String?> lastText();
  Future<void> record(DateTime time, String text);
}

class _SharedPrefsGreetingStore implements GreetingStore {
  static const _kTime = 'glimpse_ask_last_greeting_time';
  static const _kText = 'glimpse_ask_last_greeting_text';

  @override
  Future<DateTime?> lastTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kTime);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<String?> lastText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kText);
  }

  @override
  Future<void> record(DateTime time, String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTime, time.millisecondsSinceEpoch);
    await prefs.setString(_kText, text);
  }
}

/// In-memory store for testing.
class MemoryGreetingStore implements GreetingStore {
  DateTime? _time;
  String? _text;

  @override
  Future<DateTime?> lastTime() async => _time;

  @override
  Future<String?> lastText() async => _text;

  @override
  Future<void> record(DateTime time, String text) async {
    _time = time;
    _text = text;
  }
}

// ---------------------------------------------------------------------------
// Time buckets
// ---------------------------------------------------------------------------

enum TimeBucket {
  earlyMorning, // 05:00–07:59
  morning, // 08:00–11:59
  afternoon, // 12:00–15:59
  evening, // 16:00–18:59
  night, // 19:00–22:29
  lateNight, // 22:30–04:59
}

TimeBucket _timeBucketFromDateTime(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute;
  final totalMinutes = h * 60 + m;

  // lateNight: 22:30 (1350 min) through 04:59 (299 min)
  if (totalMinutes >= 1350 || totalMinutes < 300) {
    return TimeBucket.lateNight;
  }
  if (totalMinutes < 480) return TimeBucket.earlyMorning; // 5:00–7:59
  if (totalMinutes < 720) return TimeBucket.morning; // 8:00–11:59
  if (totalMinutes < 960) return TimeBucket.afternoon; // 12:00–15:59
  if (totalMinutes < 1140) return TimeBucket.evening; // 16:00–18:59
  return TimeBucket.night; // 19:00–22:29
}

// ---------------------------------------------------------------------------
// Greeting variants with metadata
// ---------------------------------------------------------------------------

class _Variant {
  const _Variant(this.text, {this.nameEligible = true});
  final String text;
  final bool nameEligible;
}

const _kEarlyMorning = <_Variant>[
  _Variant('Up early'),
  _Variant('What are we exploring today?', nameEligible: false),
  _Variant('Ready to dive in?', nameEligible: false),
  _Variant('Early start'),
];

const _kMorning = <_Variant>[
  _Variant('Good morning'),
  _Variant('What are we exploring today?', nameEligible: false),
  _Variant('Ready to dive in?', nameEligible: false),
  _Variant('Morning'),
  _Variant('What caught your attention?', nameEligible: false),
];

const _kAfternoon = <_Variant>[
  _Variant('Good afternoon'),
  _Variant('What are we exploring?', nameEligible: false),
  _Variant('Still curious?', nameEligible: false),
  _Variant('Afternoon'),
];

const _kEvening = <_Variant>[
  _Variant('Good evening'),
  _Variant('What caught your attention today?', nameEligible: false),
  _Variant('Want to revisit something?', nameEligible: false),
  _Variant('Evening'),
];

const _kNight = <_Variant>[
  _Variant('Still curious tonight?', nameEligible: false),
  _Variant('What are we exploring tonight?', nameEligible: false),
  _Variant('Night'),
  _Variant('Up for a quick dive?', nameEligible: false),
];

const _kLateNight = <_Variant>[
  _Variant('Still curious tonight?', nameEligible: false),
  _Variant('Up late again?', nameEligible: false),
  _Variant('Deep dive mode?', nameEligible: false),
  _Variant('What are we exploring tonight?', nameEligible: false),
];

List<_Variant> _variantsForBucket(TimeBucket bucket) {
  switch (bucket) {
    case TimeBucket.earlyMorning:
      return _kEarlyMorning;
    case TimeBucket.morning:
      return _kMorning;
    case TimeBucket.afternoon:
      return _kAfternoon;
    case TimeBucket.evening:
      return _kEvening;
    case TimeBucket.night:
      return _kNight;
    case TimeBucket.lateNight:
      return _kLateNight;
  }
}

// ---------------------------------------------------------------------------
// User context
// ---------------------------------------------------------------------------

enum UserContext {
  newcomer,
  returningAfterGap,
  returning,
  active,
}

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

class AskGreeting {
  const AskGreeting({
    required this.line,
    required this.phase,
    required this.context,
    this.hint,
  });

  /// Primary greeting line, e.g. "Good morning, Alex." or "Still curious?"
  final String line;

  /// Optional hint for newcomers (0 saved links). Null otherwise.
  final String? hint;

  /// Detected time bucket.
  final TimeBucket phase;

  /// Detected user context.
  final UserContext context;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class AskGreetingService {
  AskGreetingService({
    DateTime? now,
    Random? random,
    GreetingStore? store,
  })  : _now = now ?? DateTime.now(),
        _random = random ?? Random(),
        _store = store ?? _SharedPrefsGreetingStore();

  final DateTime _now;
  final Random _random;
  final GreetingStore _store;

  /// Probability of appending the user's name when eligible.
  static const _nameChance = 0.35;

  /// Gap thresholds for context detection.
  static const _gapThreshold = Duration(hours: 24);
  static const _shortGapThreshold = Duration(hours: 6);

  /// Build the greeting for the current session.
  Future<AskGreeting> build({
    required int savedUrlCount,
    String? userName,
  }) async {
    final bucket = _timeBucketFromDateTime(_now);
    final lastTime = await _store.lastTime();
    final context = _detectContext(savedUrlCount, lastTime);
    final raw = await _pickGreeting(bucket);

    final name = userName?.trim();
    final shouldUseName = _shouldUseName(
      name: name,
      variant: raw,
      context: context,
      lastTime: lastTime,
    );

    final line = shouldUseName ? '${raw.text}, $name.' : '${raw.text}.';

    await _store.record(_now, raw.text);

    return AskGreeting(
      line: line,
      hint: context == UserContext.newcomer ? 'Save your first link' : null,
      phase: bucket,
      context: context,
    );
  }

  // -------------------------------------------------------------------------
  // Context detection
  // -------------------------------------------------------------------------

  UserContext _detectContext(int savedUrlCount, DateTime? lastTime) {
    if (savedUrlCount == 0) return UserContext.newcomer;
    if (lastTime == null) return UserContext.returning;

    final gap = _now.difference(lastTime);
    if (gap > _gapThreshold) return UserContext.returningAfterGap;
    if (gap > _shortGapThreshold) return UserContext.returning;
    return UserContext.active;
  }

  // -------------------------------------------------------------------------
  // Name decision
  // -------------------------------------------------------------------------

  bool _shouldUseName({
    required String? name,
    required _Variant variant,
    required UserContext context,
    required DateTime? lastTime,
  }) {
    if (name == null || name.isEmpty) return false;
    if (!variant.nameEligible) return false;

    final isFirstSessionToday = _isFirstSessionOfDay(lastTime);
    final isReturning =
        context == UserContext.returning ||
        context == UserContext.returningAfterGap;

    if (!isFirstSessionToday && !isReturning) return false;

    return _random.nextDouble() < _nameChance;
  }

  bool _isFirstSessionOfDay(DateTime? lastTime) {
    if (lastTime == null) return true;
    final today = DateTime(_now.year, _now.month, _now.day);
    final lastDay = DateTime(lastTime.year, lastTime.month, lastTime.day);
    return today != lastDay;
  }

  // -------------------------------------------------------------------------
  // Greeting selection (with memory)
  // -------------------------------------------------------------------------

  Future<_Variant> _pickGreeting(TimeBucket bucket) async {
    final pool = _variantsForBucket(bucket);
    if (pool.length == 1) return pool.first;

    final lastText = await _store.lastText();

    // Filter out the exact last greeting to avoid immediate repetition.
    final candidates = pool.where((v) => v.text != lastText).toList();

    final effectivePool = candidates.isNotEmpty ? candidates : pool;
    final index = _random.nextInt(effectivePool.length);
    return effectivePool[index];
  }
}
