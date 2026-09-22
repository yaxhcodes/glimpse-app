import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/features/collections/share_capture_sheet.dart';

void main() {
  testWidgets('captures immediately and leaves only optional editing', (
    tester,
  ) async {
    final inbox = _collection(1, 'Inbox');
    var captures = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(_FakeIsarService([inbox])),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShareCaptureSheet(
                context,
                onCapture: (collection, notes) async {
                  captures++;
                  expect(collection?.id, 1);
                  expect(notes, isNull);
                  return const ShareCaptureOutcome(
                    type: ShareCaptureOutcomeType.captured,
                  );
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(captures, 1);
    expect(find.byTooltip('Done'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('collection changes and notes are explicit post-save edits', (
    tester,
  ) async {
    final inbox = _collection(1, 'Inbox');
    final reading = _collection(2, 'Reading');
    var captures = 0;
    var updates = 0;
    String? updatedNote;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(
            _FakeIsarService([inbox, reading]),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShareCaptureSheet(
                context,
                onCapture: (collection, notes) async {
                  captures++;
                  return ShareCaptureOutcome(
                    type: ShareCaptureOutcomeType.captured,
                    savedUrlId: 4,
                    collectionName: collection?.name,
                  );
                },
                onUpdate: (collection, notes) async {
                  updates++;
                  updatedNote = notes;
                  return ShareCaptureOutcome(
                    type: ShareCaptureOutcomeType.captured,
                    savedUrlId: 4,
                    collectionName: collection?.name,
                  );
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();
    expect(captures, 1);
    expect(updates, 1);
    await tester.tap(find.text('Add a note (optional)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Keep this  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(updates, 2);
    expect(updatedNote, 'Keep this');
  });

  testWidgets('dismissed share capture ignores a late collection result', (
    tester,
  ) async {
    final completer = Completer<List<UserCollection>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(
            _FakeIsarServiceFuture(completer.future),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShareCaptureSheet(
                context,
                onCapture: (_, _) async => const ShareCaptureOutcome(
                  type: ShareCaptureOutcomeType.captured,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(const []);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

UserCollection _collection(int id, String name) {
  return UserCollection()
    ..id = id
    ..name = name
    ..emoji = ''
    ..urlIds = []
    ..createdAt = DateTime(2026);
}

class _FakeIsarService implements IsarService {
  _FakeIsarService(this.items);

  final List<UserCollection> items;

  @override
  Future<List<UserCollection>> getAllCollections() async => items;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
  }
}

class _FakeIsarServiceFuture implements IsarService {
  _FakeIsarServiceFuture(this.items);

  final Future<List<UserCollection>> items;

  @override
  Future<List<UserCollection>> getAllCollections() => items;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
  }
}
