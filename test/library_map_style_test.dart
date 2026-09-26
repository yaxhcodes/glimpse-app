import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/library/library_map_style.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6B7F4E));
  final palette = LibraryMapPalette.fromScheme(scheme);
  Map<String, dynamic> layer(Map<String, dynamic> style, String id) =>
      (style['layers'] as List).cast<Map<String, dynamic>>().singleWhere(
        (layer) => layer['id'] == id,
      );

  final base = <String, dynamic>{
    'version': 8,
    'sources': {'openmaptiles': <String, dynamic>{}},
    'layers': [
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': '#f8f4f0'},
      },
      {
        'id': 'water',
        'type': 'fill',
        'source-layer': 'water',
        'paint': {'fill-color': 'hsl(205, 56%, 73%)'},
      },
      {
        'id': 'water-pattern',
        'type': 'fill',
        'source-layer': 'water',
        'paint': {'fill-pattern': 'wave'},
      },
      {
        'id': 'highway-motorway',
        'type': 'line',
        'source-layer': 'transportation',
        'paint': {'line-color': '#fc8', 'line-width': 2},
      },
      {
        'id': 'highway-motorway-casing',
        'type': 'line',
        'source-layer': 'transportation',
        'paint': {'line-color': '#e9ac77'},
      },
      {
        'id': 'poi-level-1',
        'type': 'symbol',
        'source-layer': 'poi',
        'layout': {'text-field': '{name}'},
      },
      {
        'id': 'place-city',
        'type': 'symbol',
        'source-layer': 'place',
        'layout': {'text-field': '{name:latin}', 'icon-image': 'dot'},
        'paint': {'text-color': '#333'},
      },
    ],
  };

  test('recolours the base layers from the app palette', () {
    final themed = themeLibraryMapStyle(base, palette);
    expect(
      layer(themed, 'background')['paint']['background-color'],
      libraryMapColorHex(palette.land),
    );
    expect(
      layer(themed, 'water')['paint']['fill-color'],
      libraryMapColorHex(palette.water),
    );
    expect(
      layer(themed, 'highway-motorway')['paint']['line-color'],
      libraryMapColorHex(palette.roadMajor),
    );
    expect(layer(themed, 'highway-motorway')['paint']['line-width'], 2);
    expect(
      layer(themed, 'highway-motorway-casing')['paint']['line-color'],
      libraryMapColorHex(palette.roadCasing),
    );
  });

  test('quiets clutter that competes with the pins', () {
    final themed = themeLibraryMapStyle(base, palette);
    expect(layer(themed, 'water-pattern')['layout']['visibility'], 'none');
    expect(layer(themed, 'poi-level-1')['layout']['visibility'], 'none');
    final city = layer(themed, 'place-city');
    expect(city['layout']['text-field'], libraryMapEnglishName);
    expect(city['layout'].containsKey('icon-image'), isFalse);
    expect(city['paint']['text-color'], libraryMapColorHex(palette.label));
  });

  test('leaves the source style untouched', () {
    themeLibraryMapStyle(base, palette);
    expect(layer(base, 'water')['paint']['fill-color'], 'hsl(205, 56%, 73%)');
  });

  test('dark water sits below the land', () {
    final dark = LibraryMapPalette.fromScheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B7F4E),
        brightness: Brightness.dark,
      ),
    );
    expect(
      dark.water.computeLuminance(),
      lessThan(dark.land.computeLuminance()),
    );
  });
}
