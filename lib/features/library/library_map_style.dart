import 'package:flutter/material.dart';

/// Map colours drawn from the app's own [ColorScheme], so the basemap sits in
/// the same palette as the sheet over it (cream and sage in the Glimpse
/// theme, the wallpaper tones under Dynamic) instead of the stock
/// OSM Bright / Dark Matter look.
@immutable
class LibraryMapPalette {
  const LibraryMapPalette({
    required this.land,
    required this.landuse,
    required this.park,
    required this.wood,
    required this.ice,
    required this.water,
    required this.waterLine,
    required this.building,
    required this.roadMajor,
    required this.roadMinor,
    required this.roadPath,
    required this.roadCasing,
    required this.rail,
    required this.boundaryCountry,
    required this.boundaryRegion,
    required this.labelStrong,
    required this.label,
    required this.labelMuted,
    required this.waterLabel,
  });

  factory LibraryMapPalette.fromScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    // A step off the sheet's surface so the sheet edge still reads.
    final land = dark ? scheme.surfaceContainer : scheme.surfaceContainerLow;
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    // Hues stay recognisable (water reads as water, parks as parks) but are
    // pulled most of the way toward the land tone so nothing shouts over pins.
    final water = dark
        ? mix(land, const Color(0xFF0E1A26), 0.72)
        : mix(land, const Color(0xFFA7C8E0), 0.78);
    return LibraryMapPalette(
      land: land,
      landuse: mix(land, scheme.onSurface, dark ? 0.03 : 0.035),
      park: dark
          ? mix(land, const Color(0xFF203526), 0.62)
          : mix(land, const Color(0xFFBFDBAE), 0.62),
      wood: dark
          ? mix(land, const Color(0xFF1C3020), 0.58)
          : mix(land, const Color(0xFFADD29A), 0.5),
      ice: dark
          ? mix(land, const Color(0xFF34404A), 0.45)
          : mix(land, Colors.white, 0.65),
      water: water,
      waterLine: dark
          ? mix(water, const Color(0xFF28435C), 0.4)
          : mix(water, const Color(0xFF7FAED0), 0.45),
      building: mix(land, scheme.onSurface, dark ? 0.07 : 0.075),
      roadMajor: dark
          ? mix(land, scheme.onSurface, 0.2)
          : mix(land, Colors.white, 0.92),
      roadMinor: dark
          ? mix(land, scheme.onSurface, 0.12)
          : mix(land, Colors.white, 0.7),
      roadPath: mix(land, scheme.onSurface, dark ? 0.1 : 0.16),
      roadCasing: dark
          ? mix(land, Colors.black, 0.3)
          : mix(land, scheme.onSurface, 0.12),
      rail: mix(land, scheme.onSurface, dark ? 0.18 : 0.2),
      boundaryCountry: mix(land, scheme.onSurfaceVariant, dark ? 0.5 : 0.45),
      boundaryRegion: mix(land, scheme.onSurfaceVariant, dark ? 0.28 : 0.25),
      labelStrong: mix(land, scheme.onSurface, 0.9),
      label: mix(land, scheme.onSurface, 0.74),
      labelMuted: mix(land, scheme.onSurfaceVariant, 0.72),
      waterLabel: dark
          ? mix(water, const Color(0xFF9DB8D0), 0.62)
          : mix(water, const Color(0xFF2F5A7A), 0.78),
    );
  }

  final Color land;
  final Color landuse;
  final Color park;
  final Color wood;
  final Color ice;
  final Color water;
  final Color waterLine;
  final Color building;
  final Color roadMajor;
  final Color roadMinor;
  final Color roadPath;
  final Color roadCasing;
  final Color rail;
  final Color boundaryCountry;
  final Color boundaryRegion;
  final Color labelStrong;
  final Color label;
  final Color labelMuted;
  final Color waterLabel;

  /// Identifies the palette for style caching.
  String get signature =>
      [land, water, park, roadMajor, label].map(libraryMapColorHex).join();
}

String libraryMapColorHex(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// English names where the tiles carry one; local script otherwise.
const libraryMapEnglishName = [
  'coalesce',
  ['get', 'name:en'],
  ['get', 'name_en'],
  ['get', 'name:latin'],
  ['get', 'name'],
];

/// Returns a copy of an OpenMapTiles-schema [style] (OSM Bright, Dark Matter,
/// Positron…) recoloured with [palette]. Layers are recognised by type,
/// source layer and id, so it holds for any of the provider's variants.
///
/// Also quiets the base map for a map whose subject is the user's pins:
/// shop/POI icons, road shields, house numbers and one-way arrows are hidden,
/// and labels use English names.
Map<String, dynamic> themeLibraryMapStyle(
  Map<String, dynamic> style,
  LibraryMapPalette palette,
) {
  final themed = Map<String, dynamic>.from(style);
  final layers = style['layers'];
  if (layers is! List) return themed;
  themed['layers'] = [
    for (final layer in layers)
      if (layer is Map) _themeLayer(Map<String, dynamic>.from(layer), palette),
  ];
  return themed;
}

Map<String, dynamic> _themeLayer(
  Map<String, dynamic> layer,
  LibraryMapPalette p,
) {
  final type = layer['type'] as String? ?? '';
  final sourceLayer = (layer['source-layer'] as String? ?? '').toLowerCase();
  final id = (layer['id'] as String? ?? '').toLowerCase();
  final paint = Map<String, dynamic>.from(
    layer['paint'] as Map? ?? const <String, dynamic>{},
  );
  final layout = Map<String, dynamic>.from(
    layer['layout'] as Map? ?? const <String, dynamic>{},
  );
  String hex(Color color) => libraryMapColorHex(color);
  bool idHas(List<String> words) => words.any(id.contains);

  void hide() => layout['visibility'] = 'none';

  void fill(Color color, {double? opacity}) {
    paint
      ..remove('fill-pattern')
      ..remove('fill-outline-color')
      ..['fill-color'] = hex(color);
    if (opacity != null) paint['fill-opacity'] = opacity;
  }

  void line(Color color, {double? opacity}) {
    paint
      ..remove('line-pattern')
      ..['line-color'] = hex(color);
    if (opacity != null) paint['line-opacity'] = opacity;
  }

  void text(Color color, {Color? halo, double haloWidth = 1.4}) {
    paint
      ..['text-color'] = hex(color)
      ..['text-halo-color'] = hex(halo ?? p.land)
      ..['text-halo-width'] = haloWidth
      ..['text-halo-blur'] = 0.4;
    if (layout.containsKey('text-field')) {
      layout['text-field'] = libraryMapEnglishName;
    }
  }

  switch (type) {
    case 'background':
      paint
        ..remove('background-pattern')
        ..['background-color'] = hex(p.land);
    case 'fill' || 'fill-extrusion':
      switch (sourceLayer) {
        case 'water':
          if (id.contains('pattern')) {
            hide();
          } else {
            fill(p.water, opacity: id.contains('intermittent') ? 0.6 : 1);
          }
        case 'park':
          fill(p.park, opacity: 0.9);
        case 'landcover':
          if (idHas(['ice', 'glacier', 'snow'])) {
            fill(p.ice, opacity: 0.9);
          } else if (idHas(['wood', 'forest'])) {
            fill(p.wood, opacity: 0.55);
          } else if (idHas(['sand', 'beach'])) {
            fill(p.landuse, opacity: 0.8);
          } else {
            fill(p.park, opacity: 0.5);
          }
        case 'landuse':
          if (idHas(['park', 'cemetery', 'grass', 'pitch', 'garden'])) {
            fill(p.park, opacity: 0.8);
          } else {
            fill(p.landuse, opacity: 0.9);
          }
        case 'building':
          if (type == 'fill-extrusion') {
            paint['fill-extrusion-color'] = hex(p.building);
          } else {
            fill(p.building, opacity: 0.9);
          }
        case 'aeroway':
          fill(p.landuse, opacity: 0.9);
        case 'transportation' || 'transportation_area':
          fill(p.roadMinor);
      }
    case 'line':
      switch (sourceLayer) {
        case 'waterway':
          line(p.waterLine);
        case 'boundary':
          final country = idHas(['level-2', 'level_2', 'country', 'disputed']);
          line(
            country ? p.boundaryCountry : p.boundaryRegion,
            opacity: country ? 0.9 : 0.7,
          );
        case 'aeroway':
          line(idHas(['casing']) ? p.roadCasing : p.roadMinor);
        case 'transportation':
          if (id.contains('ferry')) {
            line(p.waterLine, opacity: 0.8);
          } else if (idHas(['rail', 'transit', 'hatching', 'cablecar'])) {
            line(p.rail, opacity: 0.7);
          } else if (id.contains('casing')) {
            line(p.roadCasing);
          } else if (idHas(['path', 'steps', 'track', 'service', 'pier'])) {
            line(p.roadPath);
          } else if (idHas([
            'motorway',
            'trunk',
            'primary',
            'major',
            'secondary',
          ])) {
            line(p.roadMajor);
          } else {
            line(p.roadMinor);
          }
      }
    case 'symbol':
      if (idHas(['shield', 'oneway', 'housenumber']) ||
          const {
            'poi',
            'housenumber',
            'mountain_peak',
            'aerodrome_label',
          }.contains(sourceLayer)) {
        hide();
        break;
      }
      switch (sourceLayer) {
        case 'water_name' || 'waterway':
          text(p.waterLabel, halo: p.water, haloWidth: 1);
        case 'transportation_name':
          text(p.labelMuted, haloWidth: 1.6);
        case 'place':
          // The city dots and capital stars compete with the pins.
          layout.remove('icon-image');
          if (idHas(['country', 'continent'])) {
            text(p.labelStrong);
          } else if (idHas(['state', 'province', 'region'])) {
            text(p.labelMuted);
          } else if (idHas(['city', 'town', 'capital'])) {
            text(p.label);
          } else {
            text(p.labelMuted);
          }
        default:
          text(p.labelMuted);
      }
  }
  layer['paint'] = paint;
  layer['layout'] = layout;
  return layer;
}
