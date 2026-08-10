import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/library/library_places_map.dart';

void main() {
  test('selects a proxy map style matching the active brightness', () {
    expect(
      resolveLibraryMapStyleUrl(
        brightness: Brightness.light,
        baseUrl: 'https://proxy.example',
      ),
      'https://proxy.example/library-map/style.json?theme=light',
    );
    expect(
      resolveLibraryMapStyleUrl(
        brightness: Brightness.dark,
        baseUrl: 'https://proxy.example',
      ),
      'https://proxy.example/library-map/style.json?theme=dark',
    );
  });

  test(
    'supports a dedicated dark override and preserves the legacy override',
    () {
      expect(
        resolveLibraryMapStyleUrl(
          brightness: Brightness.dark,
          baseUrl: 'https://proxy.example',
          lightOverride: 'https://maps.example/light.json',
          darkOverride: 'https://maps.example/dark.json',
        ),
        'https://maps.example/dark.json',
      );
      expect(
        resolveLibraryMapStyleUrl(
          brightness: Brightness.dark,
          baseUrl: 'https://proxy.example',
          lightOverride: 'https://maps.example/custom.json',
        ),
        'https://maps.example/custom.json',
      );
    },
  );
}
