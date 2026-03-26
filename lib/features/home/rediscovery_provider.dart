import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import 'home_provider.dart';

/// Surfaces older links topically related to the user's most recent saves.
/// Re-runs automatically whenever the URL library changes.
final rediscoveryLinksProvider = FutureProvider<List<SavedUrl>>((ref) async {
  // Rebuild whenever a URL is added or removed.
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );
  final isar = ref.read(isarServiceProvider);
  final service = RediscoveryService(isar);
  return service.getRediscoveryLinks();
});
