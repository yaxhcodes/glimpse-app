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
              onPressed: () => showShareCaptureSheet(context),
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
