import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/demo_seed_service.dart';
import 'package:glimpse/l10n/generated/app_localizations_ja.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Database extends Fake implements IsarService {
  final urls = <SavedUrl>[];
  final removed = <int>[];
  bool race = false;
  @override
  Future<List<SavedUrl>> getAllUrls() async => List.of(urls);
  @override
  Future<SavedUrl?> getAnyUrlById(int id) async =>
      urls.where((u) => u.id == id).firstOrNull;
  @override
  Future<int> saveUrl(SavedUrl url) async {
    url.id = 42;
    urls.add(url);
    if (race) {
      urls.add(
        SavedUrl()
          ..id = 43
          ..rawUrl = 'https://example.com',
      );
    }
    return 42;
  }

  @override
  Future<bool> deleteUrlPermanently(int id) async {
    removed.add(id);
    urls.removeWhere((u) => u.id == id);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('demo uses active language for reader content', () {
    final l = AppLocalizationsJa();
    final demo = DemoSeedService.buildPreview(strings: l);
    expect(demo.title, l.obSaveTitle);
    expect(demo.summary, l.obSummary);
    expect(demo.description, l.obExample);
  });
  test('completion never seeds into an existing real library', () async {
    final db = _Database()
      ..urls.add(
        SavedUrl()
          ..id = 1
          ..rawUrl = 'https://example.com',
      );
    expect(await DemoSeedService(db).seed(), 0);
    expect(db.urls.length, 1);
  });
  test('seed is idempotent and removable', () async {
    final db = _Database();
    final service = DemoSeedService(db);
    expect(await service.seed(), 42);
    expect(await service.seed(), 42);
    expect(db.urls.length, 1);
    await service.clear();
    expect(db.urls, isEmpty);
    expect(await DemoSeedService.demoId(), isNull);
  });
  test('real source is distinct from the bundled and legacy examples', () {
    final demo = DemoSeedService.buildPreview();
    expect(demo.domain, 'instagram.com');
    expect(demo.rawUrl, startsWith(DemoSeedService.sourceUrl));
    expect(DemoSeedService.isDemoUrl(DemoSeedService.sourceUrl), isFalse);
    expect(DemoSeedService.isDemoUrl(demo.rawUrl), isTrue);
    expect(DemoSeedService.isDemoUrl(DemoSeedService.legacyDemoRawUrl), isTrue);
    expect(demo.thumbnailUrl, isNull);
  });
  test(
    'an older example remains removable without treating it as a real save',
    () async {
      SharedPreferences.setMockInitialValues({'onboarding_demo_url_id': 42});
      final db = _Database()
        ..urls.add(
          DemoSeedService.buildPreview()
            ..id = 42
            ..rawUrl = DemoSeedService.legacyDemoRawUrl,
        );
      await DemoSeedService(db).clear();
      expect(db.urls, isEmpty);
      expect(db.removed, [42]);
    },
  );
  test(
    'a real save arriving during seeding removes only the example',
    () async {
      final db = _Database()..race = true;
      await DemoSeedService(db).seed();
      expect(db.urls.single.id, 43);
      expect(db.removed, [42]);
    },
  );
  test('stale demo identifier never deletes a real save', () async {
    SharedPreferences.setMockInitialValues({'onboarding_demo_url_id': 42});
    final db = _Database()
      ..urls.add(
        SavedUrl()
          ..id = 42
          ..rawUrl = 'https://example.com',
      );
    await DemoSeedService(db).clear();
    expect(db.removed, isEmpty);
  });
}
