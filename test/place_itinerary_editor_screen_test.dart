import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:glimpse/features/library/place_itinerary_editor_screen.dart';
import 'package:glimpse/features/library/place_itinerary_provider.dart';

void main() {
  testWidgets('starts an area plan with focused and want-to-visit places', (
    tester,
  ) async {
    final focused = _place('temple', status: LibraryItemStatus.unlisted);
    final planned = _place('garden', status: LibraryItemStatus.planning);
    final actions = _FakeLibraryEntityActions();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySnapshotProvider.overrideWith(
            (ref) =>
                AsyncValue.data(LibrarySnapshot(entities: [focused, planned])),
          ),
          placeItinerariesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          libraryEntityActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(
          home: PlaceItineraryEditorScreen(
            draft: PlaceItineraryDraft(
              areaKey: 'kyoto|japan',
              areaTitle: 'Kyoto',
              country: 'Japan',
              focusedEntityKey: focused.key,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A day in Kyoto'), findsOneWidget);
    expect(find.text('DAY PLAN'), findsOneWidget);
    expect(find.text('Plan with Ask Glimpse'), findsOneWidget);
    expect(find.text('temple'), findsOneWidget);
    expect(find.text('garden'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.place_rounded), findsNWidgets(2));
    final nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.decoration?.filled, isFalse);
    expect(find.text('Open route'), findsOneWidget);
    expect(actions.updated[focused.key], LibraryItemStatus.planning);
    expect(actions.updated.containsKey(planned.key), isFalse);
    expect(tester.takeException(), isNull);
  });
}

LibraryEntity _place(String key, {required LibraryItemStatus status}) {
  final mention = EnrichedMention(
    title: key,
    type: 'place',
    city: 'Kyoto',
    country: 'Japan',
    latitude: 35 + key.length / 100,
    longitude: 135 + key.length / 100,
    libraryStatus: status.name,
  );
  return LibraryEntity(
    key: key,
    provisionalKey: key,
    kind: LibraryEntityKind.place,
    mention: mention,
    sources: [
      LibrarySourceReference(
        urlId: key.hashCode,
        title: 'Source',
        domain: 'example.com',
        savedAt: DateTime(2026, 8, 1),
        provisionalKey: key,
        mention: mention,
      ),
    ],
    discoveredAt: DateTime(2026, 8, 1),
  );
}

class _FakeLibraryEntityActions implements LibraryEntityActions {
  final Map<String, LibraryItemStatus> updated = {};

  @override
  Future<void> setStatus(LibraryEntity entity, LibraryItemStatus status) async {
    updated[entity.key] = status;
  }
}
