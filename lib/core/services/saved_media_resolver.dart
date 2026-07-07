import 'dart:convert';

import '../models/saved_url.dart';

class SavedMediaResolver {
  SavedMediaResolver._();

  static List<String> imageCandidates(SavedUrl url) {
    final seen = <String>{};
    final out = <String>[];

    void add(Object? value) {
      if (value is Iterable) {
        for (final item in value) {
          add(item);
        }
        return;
      }

      final imageUrl = value?.toString().trim() ?? '';
      if (imageUrl.isEmpty || !imageUrl.startsWith(RegExp(r'https?://'))) {
        return;
      }
      if (seen.add(imageUrl)) out.add(imageUrl);
    }

    add(url.thumbnailUrl);

    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return out;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return out;
      final data = Map<String, dynamic>.from(decoded);
      add(data['thumbnail_url']);
      add(data['thumbnailUrl']);
      add(data['image_urls']);
      add(data['imageUrls']);
      add(data['images']);

      final recipe = data['recipe'];
      if (recipe is Map) {
        add(recipe['image']);
        add(recipe['thumbnail_url']);
        add(recipe['thumbnailUrl']);
      }
    } catch (_) {
      return out;
    }

    return out;
  }

  static Map<String, String>? imageHttpHeaders(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    final lower = imageUrl.toLowerCase();
    if (lower.contains('cdninstagram.com') || lower.contains('fbcdn.net')) {
      return {'Referer': 'https://www.instagram.com/'};
    }
    return null;
  }
}
