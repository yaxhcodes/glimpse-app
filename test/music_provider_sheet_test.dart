import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:glimpse/core/models/music_provider.dart';
import 'package:glimpse/shared/widgets/music_provider_sheet.dart';

void main() {
  testWidgets('returns the selected music provider', (tester) async {
    MusicProvider? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showMusicProviderSheet(context);
              },
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    expect(find.text('Where do you listen?'), findsOneWidget);
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('YouTube Music'), findsOneWidget);
    expect(find.text('Apple Music'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(3));

    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();

    expect(result, MusicProvider.spotify);
  });
}
