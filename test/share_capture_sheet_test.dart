import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/features/collections/share_capture_sheet.dart';

void main() {
  testWidgets('saves at once, then the pill gets out of the way', (
    tester,
  ) async {
    final inbox = _collection(1, 'Inbox');
    var captures = 0;
    final result = await _openCapture(
      tester,
      isar: _FakeIsarService([inbox]),
      onCapture: (collection, notes) async {
        captures++;
        expect(collection?.id, 1);
        expect(notes, isNull);
        return const ShareCaptureOutcome(
          type: ShareCaptureOutcomeType.captured,
        );
      },
    );
    await tester.pumpAndSettle();
    expect(captures, 1);
    expect(find.text('Saved to Glimpse'), findsOneWidget);
    expect(find.text('Collection'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Saved to Glimpse'), findsNothing);
    expect((await result)?.type, ShareCaptureOutcomeType.captured);
  });

  testWidgets('choosing a collection moves the save and confirms it', (
    tester,
  ) async {
    final inbox = _collection(1, 'Inbox');
    final reading = _collection(2, 'Reading');
    var updates = 0;
    UserCollection? moved;
    final result = await _openCapture(
      tester,
      isar: _FakeIsarService([inbox, reading]),
      onCapture: (collection, notes) async => const ShareCaptureOutcome(
        type: ShareCaptureOutcomeType.captured,
        savedUrlId: 4,
      ),
      onUpdate: (collection, notes) async {
        updates++;
        moved = collection;
        return ShareCaptureOutcome(
          type: ShareCaptureOutcomeType.captured,
          savedUrlId: 4,
          collectionName: collection?.name,
        );
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();
    expect(updates, 1);
    expect(moved?.id, 2);
    expect(find.text('Saved to Reading'), findsOneWidget);
    // Filing it doesn't close the door on a note.
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Collection'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect((await result)?.collectionName, 'Reading');
  });

  testWidgets('a note is an explicit edit on the landed save', (tester) async {
    final inbox = _collection(1, 'Inbox');
    String? updatedNote;
    UserCollection? noteCollection;
    await _openCapture(
      tester,
      isar: _FakeIsarService([inbox]),
      onCapture: (collection, notes) async => const ShareCaptureOutcome(
        type: ShareCaptureOutcomeType.captured,
        savedUrlId: 4,
      ),
      onUpdate: (collection, notes) async {
        updatedNote = notes;
        noteCollection = collection;
        return const ShareCaptureOutcome(
          type: ShareCaptureOutcomeType.captured,
          savedUrlId: 4,
        );
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Keep this  ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(updatedNote, 'Keep this');
    expect(noteCollection?.id, 1);
    expect(find.text('Note added'), findsOneWidget);
    expect(find.text('Collection'), findsOneWidget);
    expect(find.text('Note'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Note added'), findsNothing);
  });

  testWidgets('one share can take both a collection and a note', (
    tester,
  ) async {
    final inbox = _collection(1, 'Inbox');
    final reading = _collection(2, 'Reading');
    final edits = <(int?, String?)>[];
    final result = await _openCapture(
      tester,
      isar: _FakeIsarService([inbox, reading]),
      onCapture: (collection, notes) async => const ShareCaptureOutcome(
        type: ShareCaptureOutcomeType.captured,
        savedUrlId: 4,
      ),
      onUpdate: (collection, notes) async {
        edits.add((collection?.id, notes));
        return ShareCaptureOutcome(
          type: ShareCaptureOutcomeType.captured,
          savedUrlId: 4,
          collectionName: collection?.name,
        );
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'For Sunday');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The note lands on the collection just chosen, not back in Inbox.
    expect(edits, [(2, null), (2, 'For Sunday')]);
    expect(find.text('Note added'), findsOneWidget);
    expect(find.text('Collection'), findsNothing);
    expect(find.text('Note'), findsNothing);

    // Nothing left to offer, so it only confirms briefly.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Note added'), findsNothing);
    expect((await result)?.saved, isTrue);
  });

  testWidgets('tapping away while saving closes once the save lands', (
    tester,
  ) async {
    final save = Completer<ShareCaptureOutcome>();
    final result = await _openCapture(
      tester,
      isar: _FakeIsarService(const []),
      onCapture: (_, _) => save.future,
    );
    // No loader: the pill reads as saved, with its edits, from the start.
    expect(find.text('Saved to Glimpse'), findsOneWidget);
    expect(find.text('Collection'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.text('Saved to Glimpse'), findsOneWidget);

    save.complete(
      const ShareCaptureOutcome(type: ShareCaptureOutcomeType.captured),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved to Glimpse'), findsNothing);
    expect((await result)?.saved, isTrue);
  });

  testWidgets('a note made before the save lands waits for it', (
    tester,
  ) async {
    final save = Completer<ShareCaptureOutcome>();
    String? updatedNote;
    await _openCapture(
      tester,
      isar: _FakeIsarService(const []),
      onCapture: (_, _) => save.future,
      onUpdate: (_, notes) async {
        updatedNote = notes;
        return const ShareCaptureOutcome(
          type: ShareCaptureOutcomeType.captured,
          savedUrlId: 4,
        );
      },
    );
    await tester.tap(find.text('Note'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Early thought');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(updatedNote, isNull);

    save.complete(
      const ShareCaptureOutcome(
        type: ShareCaptureOutcomeType.captured,
        savedUrlId: 4,
      ),
    );
    await tester.pumpAndSettle();
    expect(updatedNote, 'Early thought');
    expect(find.text('Note added'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a save that fails says so and offers Retry', (tester) async {
    var attempts = 0;
    await _openCapture(
      tester,
      isar: _FakeIsarService(const []),
      onCapture: (_, _) async {
        attempts++;
        return ShareCaptureOutcome(
          type: attempts == 1
              ? ShareCaptureOutcomeType.error
              : ShareCaptureOutcomeType.captured,
        );
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t save this link'), findsOneWidget);
    expect(find.text('Note'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Saved to Glimpse'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('tapping away keeps a typed note instead of dropping it', (
    tester,
  ) async {
    String? updatedNote;
    final result = await _openCapture(
      tester,
      isar: _FakeIsarService(const []),
      onCapture: (_, _) async => const ShareCaptureOutcome(
        type: ShareCaptureOutcomeType.captured,
        savedUrlId: 4,
      ),
      onUpdate: (_, notes) async {
        updatedNote = notes;
        return const ShareCaptureOutcome(
          type: ShareCaptureOutcomeType.captured,
          savedUrlId: 4,
        );
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Read later');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(updatedNote, 'Read later');
    expect((await result)?.saved, isTrue);
  });

  testWidgets('dismissed share capture ignores a late collection result', (
    tester,
  ) async {
    final completer = Completer<List<UserCollection>>();
    await _openCapture(
      tester,
      isar: _FakeIsarServiceFuture(completer.future),
      onCapture: (_, _) async =>
          const ShareCaptureOutcome(type: ShareCaptureOutcomeType.captured),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(const []);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

/// Opens the capture and pumps through its entrance. Callers settle
/// themselves, since a save held in flight keeps the loader spinning.
Future<Future<ShareCaptureOutcome?>> _openCapture(
  WidgetTester tester, {
  required IsarService isar,
  required ShareCaptureCallback onCapture,
  ShareCaptureCallback? onUpdate,
}) async {
  late Future<ShareCaptureOutcome?> result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [isarServiceProvider.overrideWithValue(isar)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showShareCapture(
              context,
              onCapture: onCapture,
              onUpdate: onUpdate,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return result;
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
