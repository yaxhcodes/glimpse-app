import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';

final collectionsListProvider =
    FutureProvider<List<UserCollection>>((ref) async {
  final isar = ref.watch(isarServiceProvider);
  return isar.getAllCollections();
});

final collectionMetaProvider =
    FutureProvider.family<UserCollection?, int>((ref, id) async {
  final isar = ref.watch(isarServiceProvider);
  return isar.getCollectionById(id);
});

final collectionUrlsProvider =
    FutureProvider.family<List<SavedUrl>, int>((ref, id) async {
  final isar = ref.watch(isarServiceProvider);
  return isar.getUrlsInCollection(id);
});
