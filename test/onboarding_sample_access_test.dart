import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/core/providers/usage_providers.dart';
import 'package:glimpse/core/services/demo_seed_service.dart';
import 'package:glimpse/features/ask/ask_provider.dart';
import 'package:glimpse/features/search/search_provider.dart';

class _SampleDatabase extends Fake implements IsarService {
  final sample = DemoSeedService.buildPreview()..id = 42;
  @override
  Future<List<SavedUrl>> getAllUrls() async => [sample];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #logEvent) return Future<void>.value();
    if (invocation.memberName == #keywordSearchWithScores) {
      return Future.value([MapEntry(sample, 1.0)]);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stale in [false, true]) {
    test('sample Ask stays local and unmetered (removed: $stale)', () async {
      SharedPreferences.setMockInitialValues(
        stale ? {} : {'onboarding_demo_url_id': 42},
      );
      final database = _SampleDatabase();
      var quotaReads = 0;
      var apiReads = 0;
      final container = ProviderContainer(
        overrides: [
          isarServiceProvider.overrideWithValue(database),
          usageServiceProvider.overrideWith((ref) {
            quotaReads++;
            throw StateError('sample quota access');
          }),
          geminiServiceProvider.overrideWith((ref) {
            apiReads++;
            throw StateError('sample API access');
          }),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(askProvider.notifier)
          .ask(
            'What did I save about France?',
            preloadedSources: stale ? [database.sample] : null,
          );
      final reply = container.read(askProvider).messages.last;
      expect(reply.text, contains('Illustrative example'));
      expect(reply.canSaveAsNote, false);
      expect(quotaReads, 0);
      expect(apiReads, 0);
    });
  }
  test(
    'sample-only search never checks quota or requests embeddings',
    () async {
      SharedPreferences.setMockInitialValues({'onboarding_demo_url_id': 42});
      var quotaReads = 0;
      var embeddingReads = 0;
      final container = ProviderContainer(
        overrides: [
          isarServiceProvider.overrideWithValue(_SampleDatabase()),
          usageServiceProvider.overrideWith((ref) {
            quotaReads++;
            throw StateError('sample quota access');
          }),
          embeddingServiceProvider.overrideWith((ref) {
            embeddingReads++;
            throw StateError('sample embeddings');
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(searchProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(searchProvider.notifier).search('France');
      expect(container.read(searchProvider).valueOrNull?.single.url.id, 42);
      expect(quotaReads, 0);
      expect(embeddingReads, 0);
    },
  );
}
