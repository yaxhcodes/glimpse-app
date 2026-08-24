import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/features/collections/share_capture_sheet.dart';

void main() {
  testWidgets('dismissed share capture ignores a late collection result', (
    tester,
  ) async {
    final completer = Completer<List<UserCollection>>();
    final isar = _DelayedIsarService(completer.future);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isarServiceProvider.overrideWithValue(isar)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShareCaptureSheet(
                context,
                onCapture: (_) async => const ShareCaptureOutcome(
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

  testWidgets('shows a quiet captured confirmation before closing', (
    tester,
  ) async {
    final isar = _DelayedIsarService(Future.value(const []));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isarServiceProvider.overrideWithValue(isar)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShareCaptureSheet(
                context,
                onCapture: (_) async => const ShareCaptureOutcome(
                  type: ShareCaptureOutcomeType.captured,
                  notificationsEnabled: true,
                  enrichmentPending: true,
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('Captured'), findsOneWidget);
    expect(find.text('We’ll notify you when it’s ready.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Captured'), findsNothing);
  });

  testWidgets('does not promise a notification when notifications are off', (
    tester,
  ) async {
    final isar = _DelayedIsarService(Future.value(const []));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isarServiceProvider.overrideWithValue(isar)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShareCaptureSheet(
                context,
                onCapture: (_) async => const ShareCaptureOutcome(
                  type: ShareCaptureOutcomeType.captured,
                  enrichmentPending: true,
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('It’ll be ready in Glimpse.'), findsOneWidget);
    expect(find.text('We’ll notify you when it’s ready.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets('shows the scheduling fallback without a notification promise', (
    tester,
  ) async {
    final isar = _DelayedIsarService(Future.value(const []));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isarServiceProvider.overrideWithValue(isar)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShareCaptureSheet(
                context,
                onCapture: (_) async => const ShareCaptureOutcome(
                  type: ShareCaptureOutcomeType.schedulingFallback,
                  notificationsEnabled: true,
                  enrichmentPending: true,
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(
      find.text('Saved. Open Glimpse to finish organizing it.'),
      findsOneWidget,
    );
    expect(find.text('We’ll notify you when it’s ready.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });
}

class _DelayedIsarService implements IsarService {
  const _DelayedIsarService(this.collections);

  final Future<List<UserCollection>> collections;

  @override
  Future<List<UserCollection>> getAllCollections() => collections;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
  }
}
