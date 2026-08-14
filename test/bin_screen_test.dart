import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/features/settings/bin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('swiping right restores a binned item', (tester) async {
    final isar = _FakeBinIsarService([_savedUrl(1, 'First save')]);
    addTearDown(isar.dispose);
    await _pumpBin(tester, isar);

    await tester.drag(find.text('First save'), const Offset(420, 0));
    await tester.pumpAndSettle();

    expect(isar.restoredIds, {1});
    expect(find.text('First save'), findsNothing);
    expect(find.text('Restored'), findsOneWidget);
  });

  testWidgets('swiping left confirms permanent deletion', (tester) async {
    final isar = _FakeBinIsarService([_savedUrl(1, 'First save')]);
    addTearDown(isar.dispose);
    await _pumpBin(tester, isar);

    await tester.drag(find.text('First save'), const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete permanently?'), findsOneWidget);
    expect(isar.deletedIds, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('First save'), findsOneWidget);
    expect(isar.deletedIds, isEmpty);
  });

  testWidgets('long press enables bulk restore selection', (tester) async {
    final isar = _FakeBinIsarService([
      _savedUrl(1, 'First save'),
      _savedUrl(2, 'Second save'),
    ]);
    addTearDown(isar.dispose);
    await _pumpBin(tester, isar);

    await tester.longPress(find.text('First save'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Exit selection'), findsOneWidget);
    expect(find.byTooltip('Restore selected'), findsOneWidget);
    expect(find.byTooltip('Delete selected permanently'), findsOneWidget);

    await tester.tap(find.text('Second save'));
    await tester.pump();
    await tester.tap(find.byTooltip('Restore selected'));
    await tester.pumpAndSettle();

    expect(isar.restoredIds, {1, 2});
    expect(find.text('2 items restored'), findsOneWidget);
    expect(find.byTooltip('Exit selection'), findsNothing);
  });

  testWidgets('overflow menu exposes both item actions', (tester) async {
    final isar = _FakeBinIsarService([_savedUrl(1, 'First save')]);
    addTearDown(isar.dispose);
    await _pumpBin(tester, isar);

    expect(find.byType(TextButton), findsNothing);
    await tester.tap(find.byTooltip('Item actions'));
    await tester.pumpAndSettle();

    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete permanently'), findsOneWidget);
  });
}

Future<void> _pumpBin(WidgetTester tester, _FakeBinIsarService isar) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [isarServiceProvider.overrideWithValue(isar)],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const BinScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SavedUrl _savedUrl(int id, String title) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = title
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = 'link'
    ..categories = const ['Other']
    ..tags = const []
    ..savedAt = DateTime.now().subtract(const Duration(days: 2))
    ..deletedAt = DateTime.now().subtract(const Duration(days: 1));
}

class _FakeBinIsarService implements IsarService {
  _FakeBinIsarService(List<SavedUrl> urls) : _urls = [...urls];

  final StreamController<List<SavedUrl>> _controller =
      StreamController<List<SavedUrl>>.broadcast();
  final Set<int> restoredIds = {};
  final Set<int> deletedIds = {};
  List<SavedUrl> _urls;

  @override
  Stream<List<SavedUrl>> watchBinUrls() async* {
    yield List.unmodifiable(_urls);
    yield* _controller.stream;
  }

  @override
  Future<List<int>> purgeExpiredBinItems({DateTime? now}) async => const [];

  @override
  Future<bool> restoreUrlFromBin(int id) async {
    return await restoreUrlsFromBin([id]) == 1;
  }

  @override
  Future<int> restoreUrlsFromBin(Iterable<int> ids) async {
    final requested = ids.toSet();
    final matches = _urls.where((url) => requested.contains(url.id)).toList();
    restoredIds.addAll(matches.map((url) => url.id));
    _urls = _urls.where((url) => !requested.contains(url.id)).toList();
    _emit();
    return matches.length;
  }

  @override
  Future<bool> deleteUrlPermanently(int id) async {
    return (await deleteUrlsPermanently([id])).isNotEmpty;
  }

  @override
  Future<List<int>> deleteUrlsPermanently(Iterable<int> ids) async {
    final requested = ids.toSet();
    final matches = _urls
        .where((url) => requested.contains(url.id))
        .map((url) => url.id)
        .toList();
    deletedIds.addAll(matches);
    _urls = _urls.where((url) => !requested.contains(url.id)).toList();
    _emit();
    return matches;
  }

  @override
  Future<List<int>> emptyBin() async {
    return deleteUrlsPermanently(_urls.map((url) => url.id));
  }

  void _emit() {
    _controller.add(List.unmodifiable(_urls));
  }

  Future<void> dispose() => _controller.close();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
  }
}
