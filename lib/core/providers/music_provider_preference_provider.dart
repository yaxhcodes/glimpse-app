import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_provider.dart';

const musicProviderPreferenceKey = 'glimpse_default_music_provider';

class MusicProviderPreferenceState {
  const MusicProviderPreferenceState({this.provider, this.isLoaded = false});

  final MusicProvider? provider;
  final bool isLoaded;
}

class MusicProviderPreferenceNotifier
    extends StateNotifier<MusicProviderPreferenceState> {
  MusicProviderPreferenceNotifier()
    : super(const MusicProviderPreferenceState()) {
    unawaited(ensureLoaded());
  }

  Future<void>? _loadFuture;

  Future<void> ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(musicProviderPreferenceKey);
    state = MusicProviderPreferenceState(
      provider: _decode(stored),
      isLoaded: true,
    );
  }

  Future<void> setProvider(MusicProvider provider) async {
    state = MusicProviderPreferenceState(provider: provider, isLoaded: true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(musicProviderPreferenceKey, provider.name);
  }

  MusicProvider? _decode(String? stored) {
    for (final provider in MusicProvider.values) {
      if (provider.name == stored) return provider;
    }
    return null;
  }
}

final musicProviderPreferenceProvider =
    StateNotifierProvider<
      MusicProviderPreferenceNotifier,
      MusicProviderPreferenceState
    >((ref) => MusicProviderPreferenceNotifier());
