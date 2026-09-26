import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'library_entity.dart';

const placeLocalitiesPrefsKey = 'glimpse_place_localities_v1';

/// The first-level division (state, prefecture, province…) and town a pin
/// sits in. Saved places only carry a city and a country; this fills in the
/// level between them so a country's places can be browsed by region.
@immutable
class PlaceLocality {
  const PlaceLocality({this.region, this.city});

  factory PlaceLocality.fromJson(Map<String, dynamic> json) =>
      PlaceLocality(region: _clean(json['r']), city: _clean(json['c']));

  final String? region;
  final String? city;

  Map<String, dynamic> toJson() => {'r': ?region, 'c': ?city};

  static String? _clean(Object? value) {
    final text = value is String
        ? value.replaceAll(RegExp(r'\s+'), ' ').trim()
        : '';
    return text.isEmpty ? null : text;
  }
}

/// Reverse geocoding seam; the device geocoder in the app, a fake in tests.
abstract interface class PlaceReverseGeocoder {
  Future<bool> get isAvailable;

  /// Null when the lookup failed (retry later); an empty locality when the
  /// geocoder answered but knows no region.
  Future<PlaceLocality?> lookup(double latitude, double longitude);
}

class DevicePlaceReverseGeocoder implements PlaceReverseGeocoder {
  /// Created on first use: the plugin has no platform instance in tests or
  /// on platforms without a geocoder, and constructing it there throws.
  Geocoding? get _geocoding {
    try {
      return _instance ??= Geocoding();
    } catch (_) {
      return null;
    }
  }

  Geocoding? _instance;

  // Region and town names in English, like the map labels and country chips.
  static const _locale = Locale('en', 'US');

  @override
  Future<bool> get isAvailable async {
    try {
      return await _geocoding?.isPresent() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PlaceLocality?> lookup(double latitude, double longitude) async {
    final geocoding = _geocoding;
    if (geocoding == null) return null;
    try {
      final marks = await geocoding
          .placemarkFromCoordinates(latitude, longitude, locale: _locale)
          .timeout(const Duration(seconds: 8));
      for (final mark in marks) {
        final region = mark.administrativeArea?.trim() ?? '';
        final city = [mark.locality, mark.subAdministrativeArea]
            .map((value) => value?.trim() ?? '')
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        if (region.isEmpty && city.isEmpty) continue;
        return PlaceLocality(
          region: region.isEmpty ? null : region,
          city: city.isEmpty ? null : city,
        );
      }
      return const PlaceLocality();
    } catch (error) {
      // Includes the timeout: on Android 13+ a geocoder error never
      // completes the call.
      developer.log(
        'Reverse geocoding failed; will retry next visit.',
        name: 'PlaceLocalities',
        error: error,
      );
      return null;
    }
  }
}

final placeReverseGeocoderProvider = Provider<PlaceReverseGeocoder>(
  (ref) => DevicePlaceReverseGeocoder(),
);

final placeLocalitiesProvider =
    StateNotifierProvider<PlaceLocalitiesNotifier, Map<String, PlaceLocality>>(
      (ref) => PlaceLocalitiesNotifier(ref.watch(placeReverseGeocoderProvider)),
    );

/// Looks up regions for pins in the background and remembers them by
/// coordinate, so each place is geocoded once per install.
class PlaceLocalitiesNotifier
    extends StateNotifier<Map<String, PlaceLocality>> {
  PlaceLocalitiesNotifier(this._geocoder) : super(const {}) {
    _loaded = _load();
  }

  /// Results are published in batches: every update regroups the Places
  /// sheet, and one rebuild per lookup made the list shuffle as it filled.
  static const _publishEvery = 8;

  /// Lookups that fail in a row before giving up until the next visit
  /// (offline, or a geocoder that never answers).
  static const _maxConsecutiveFailures = 3;

  final PlaceReverseGeocoder _geocoder;
  late final Future<void> _loaded;
  final Set<String> _attempted = {};
  bool _running = false;
  DateTime? _retryAfter;

  static String keyFor(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  static String? keyOf(LibraryEntity entity) {
    final mention = entity.mention;
    if (!mention.hasCoordinates) return null;
    return keyFor(mention.latitude!, mention.longitude!);
  }

  PlaceLocality? of(LibraryEntity entity) {
    final key = keyOf(entity);
    return key == null ? null : state[key];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(placeLocalitiesPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || !mounted) return;
      state = {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String && value is Map)
            key: PlaceLocality.fromJson(Map<String, dynamic>.from(value)),
        ...state,
      };
    } catch (error) {
      developer.log(
        'Stored place regions were unreadable; they will be looked up again.',
        name: 'PlaceLocalities',
        error: error,
      );
    }
  }

  /// Looks up every pinned place in [places] that has no region yet. Safe to
  /// call on every build: work already done or in flight is skipped.
  Future<void> ensure(Iterable<LibraryEntity> places) async {
    await _loaded;
    if (_running || !mounted) return;
    if (_retryAfter case final retryAfter?
        when DateTime.now().isBefore(retryAfter)) {
      return;
    }
    final pending = <String, (double, double)>{};
    for (final entity in places) {
      final key = keyOf(entity);
      if (key == null || state.containsKey(key) || _attempted.contains(key)) {
        continue;
      }
      pending[key] = (entity.mention.latitude!, entity.mention.longitude!);
    }
    if (pending.isEmpty) return;
    _running = true;
    try {
      if (!await _geocoder.isAvailable) {
        _attempted.addAll(pending.keys);
        return;
      }
      final found = <String, PlaceLocality>{};
      var failures = 0;
      for (final MapEntry(:key, value: (latitude, longitude))
          in pending.entries) {
        if (!mounted) return;
        final locality = await _geocoder.lookup(latitude, longitude);
        if (locality == null) {
          if (++failures >= _maxConsecutiveFailures) {
            _retryAfter = DateTime.now().add(const Duration(minutes: 2));
            break;
          }
          continue;
        }
        failures = 0;
        _attempted.add(key);
        found[key] = locality;
        if (found.length >= _publishEvery) {
          _publish(found);
          found.clear();
        }
      }
      _publish(found);
      await _persist();
    } finally {
      _running = false;
    }
  }

  void _publish(Map<String, PlaceLocality> found) {
    if (found.isEmpty || !mounted) return;
    state = {...state, ...found};
  }

  Future<void> _persist() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        placeLocalitiesPrefsKey,
        jsonEncode({
          for (final MapEntry(:key, :value) in state.entries)
            key: value.toJson(),
        }),
      );
    } catch (error) {
      developer.log(
        'Place regions could not be saved; they stay for this session.',
        name: 'PlaceLocalities',
        error: error,
      );
    }
  }
}
