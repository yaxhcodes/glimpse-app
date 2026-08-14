import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';

final binUrlsProvider = StreamProvider<List<SavedUrl>>((ref) {
  return ref.watch(isarServiceProvider).watchBinUrls();
});

final binCountProvider = StreamProvider<int>((ref) {
  return ref.watch(isarServiceProvider).watchBinCount();
});
