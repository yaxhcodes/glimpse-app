import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/mindmap/cluster_theme.dart';

List<ClusterTheme> interestThemesWithIncidentalTravel() => [
  ClusterTheme(
    index: 0,
    label: 'Spirituality',
    summary: '',
    urls: [for (var i = 1; i <= 4; i++) _save(i, 'Reflection', 'Forest trail')],
  ),
  ClusterTheme(
    index: 1,
    label: 'Wildlife & Nature',
    summary: '',
    urls: [
      for (var i = 5; i <= 8; i++)
        _save(i, 'Puffling Rescue Patrol', 'Westman Islands, Iceland'),
    ],
  ),
];

SavedUrl _save(int id, String title, String description) => SavedUrl()
  ..id = id
  ..rawUrl = 'https://example.com/$id'
  ..domain = 'example.com'
  ..title = title
  ..description = description
  ..category = 'Nature'
  ..categories = ['Nature']
  ..tags = ['nature']
  ..savedAt = DateTime(2026)
  ..embedding = [1, 0.1];
