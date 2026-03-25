import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';

final rediscoveryLinksProvider = FutureProvider<List<SavedUrl>>((ref) async {
  final isar = ref.watch(isarServiceProvider);
  final service = RediscoveryService(isar);
  return service.getRediscoveryLinks();
});
