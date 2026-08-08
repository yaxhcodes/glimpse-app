import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/music_provider.dart';
import 'package:glimpse/core/providers/music_provider_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts without a default and persists the selected provider', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(musicProviderPreferenceProvider.notifier);
    await notifier.ensureLoaded();

    expect(container.read(musicProviderPreferenceProvider).isLoaded, isTrue);
    expect(container.read(musicProviderPreferenceProvider).provider, isNull);

    await notifier.setProvider(MusicProvider.youtubeMusic);

    expect(
      container.read(musicProviderPreferenceProvider).provider,
      MusicProvider.youtubeMusic,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(musicProviderPreferenceKey),
      MusicProvider.youtubeMusic.name,
    );
  });

  test('restores a persisted provider', () async {
    SharedPreferences.setMockInitialValues({
      musicProviderPreferenceKey: MusicProvider.appleMusic.name,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(musicProviderPreferenceProvider.notifier)
        .ensureLoaded();

    expect(
      container.read(musicProviderPreferenceProvider).provider,
      MusicProvider.appleMusic,
    );
  });
}
