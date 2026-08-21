import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../library/library_entity.dart';
import '../library/library_provider.dart';
import '../mindmap/interest_cluster_service.dart';

const navigationDiscoveryPrefsKey = 'glimpse_navigation_discovery_v1';

@immutable
class NavigationDiscoveryState {
  const NavigationDiscoveryState({
    this.isReady = false,
    this.hasNewCollections = false,
    this.hasNewInterests = false,
    this.libraryFingerprint = '',
    this.interestFingerprint = '',
  });

  final bool isReady;
  final bool hasNewCollections;
  final bool hasNewInterests;
  final String libraryFingerprint;
  final String interestFingerprint;

  NavigationDiscoveryState copyWith({
    bool? isReady,
    bool? hasNewCollections,
    bool? hasNewInterests,
    String? libraryFingerprint,
    String? interestFingerprint,
  }) {
    return NavigationDiscoveryState(
      isReady: isReady ?? this.isReady,
      hasNewCollections: hasNewCollections ?? this.hasNewCollections,
      hasNewInterests: hasNewInterests ?? this.hasNewInterests,
      libraryFingerprint: libraryFingerprint ?? this.libraryFingerprint,
      interestFingerprint: interestFingerprint ?? this.interestFingerprint,
    );
  }

  Map<String, Object> toJson() => {
    'hasNewCollections': hasNewCollections,
    'hasNewInterests': hasNewInterests,
    'libraryFingerprint': libraryFingerprint,
    'interestFingerprint': interestFingerprint,
  };

  static NavigationDiscoveryState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final libraryFingerprint = map['libraryFingerprint'];
    final interestFingerprint = map['interestFingerprint'];
    if (libraryFingerprint is! String || interestFingerprint is! String) {
      return null;
    }
    return NavigationDiscoveryState(
      isReady: true,
      hasNewCollections: map['hasNewCollections'] == true,
      hasNewInterests: map['hasNewInterests'] == true,
      libraryFingerprint: libraryFingerprint,
      interestFingerprint: interestFingerprint,
    );
  }
}

@immutable
class NavigationDiscoveryEvaluation {
  const NavigationDiscoveryEvaluation({
    required this.hasNewCollections,
    required this.hasNewInterests,
    required this.libraryFingerprint,
    required this.interestFingerprint,
  });

  final bool hasNewCollections;
  final bool hasNewInterests;
  final String libraryFingerprint;
  final String interestFingerprint;
}

/// Evaluates only the structural contribution of [newSaveId].
///
/// Comparing the current library with a counterfactual version that omits the
/// new save makes imports, backfills, deletes, and pre-existing data inert.
@visibleForTesting
Future<NavigationDiscoveryEvaluation> evaluateNavigationDiscovery({
  required List<SavedUrl> urls,
  required int newSaveId,
  Set<String> hiddenLibraryEntityKeys = const {},
}) async {
  final newSave = urls.where((url) => url.id == newSaveId).firstOrNull;
  if (newSave == null) {
    throw StateError('New save $newSaveId is no longer available.');
  }

  final urlsWithoutNewSave = urls
      .where((url) => url.id != newSaveId)
      .toList(growable: false);
  final currentLibrary = LibraryIndex.build(
    urls,
    hiddenKeys: hiddenLibraryEntityKeys,
  );
  final previousLibrary = LibraryIndex.build(
    urlsWithoutNewSave,
    hiddenKeys: hiddenLibraryEntityKeys,
  );
  final previousEntityKeys = {
    for (final entity in previousLibrary.entities) ...[
      entity.key,
      entity.provisionalKey,
    ],
  };
  final hasNewCollections = currentLibrary.entities.any(
    (entity) =>
        !previousEntityKeys.contains(entity.key) &&
        !previousEntityKeys.contains(entity.provisionalKey),
  );

  var hasNewInterests = false;
  var interestFingerprint = '';
  if (newSave.embedding?.isNotEmpty ?? false) {
    final topologies = await Future.wait([
      buildInterestTopologySnapshot(urls),
      buildInterestTopologySnapshot(urlsWithoutNewSave),
    ]);
    final currentTopology = topologies[0];
    final previousTopology = topologies[1];
    hasNewInterests = currentTopology.addsMeaningfulStructureComparedTo(
      previousTopology,
    );
    interestFingerprint = currentTopology.fingerprint;
  }

  return NavigationDiscoveryEvaluation(
    hasNewCollections: hasNewCollections,
    hasNewInterests: hasNewInterests,
    libraryFingerprint: _fingerprintLibrary(currentLibrary),
    interestFingerprint: interestFingerprint,
  );
}

String _fingerprintLibrary(LibrarySnapshot snapshot) {
  final keys = snapshot.entities.map((entity) => entity.key).toList()..sort();
  var hash = 0x811c9dc5;
  for (final unit in keys.join('|').codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

final navigationDiscoveryProvider =
    StateNotifierProvider<
      NavigationDiscoveryNotifier,
      NavigationDiscoveryState
    >((ref) => NavigationDiscoveryNotifier(ref));

@visibleForTesting
final navigationDiscoveryUrlsLoaderProvider =
    Provider<Future<List<SavedUrl>> Function()>((ref) {
      final isar = ref.watch(isarServiceProvider);
      return isar.getAllUrls;
    });

class NavigationDiscoveryNotifier
    extends StateNotifier<NavigationDiscoveryState> {
  NavigationDiscoveryNotifier(this._ref)
    : super(const NavigationDiscoveryState()) {
    _initialization = _initialize();
  }

  final Ref _ref;
  late final Future<void> _initialization;

  Future<void> get ready => _initialization;

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(navigationDiscoveryPrefsKey);
      if (encoded != null && encoded.isNotEmpty) {
        final restored = NavigationDiscoveryState.fromJson(jsonDecode(encoded));
        if (restored != null) {
          state = restored;
          return;
        }
      }
      await _rebaseline(clearPending: true);
    } catch (error, stackTrace) {
      developer.log(
        'Could not initialize navigation discovery state.',
        name: 'NavigationDiscovery',
        error: error,
        stackTrace: stackTrace,
      );
      state = const NavigationDiscoveryState(isReady: true);
    }
  }

  Future<void> recordCompletedNewSave(int savedUrlId) async {
    await _initialization;
    try {
      final urls = await _ref.read(navigationDiscoveryUrlsLoaderProvider)();
      final hiddenKeys = await _hiddenLibraryEntityKeys();
      final evaluation = await evaluateNavigationDiscovery(
        urls: urls,
        newSaveId: savedUrlId,
        hiddenLibraryEntityKeys: hiddenKeys,
      );
      state = state.copyWith(
        isReady: true,
        hasNewCollections:
            state.hasNewCollections || evaluation.hasNewCollections,
        hasNewInterests: state.hasNewInterests || evaluation.hasNewInterests,
        libraryFingerprint: evaluation.libraryFingerprint,
        interestFingerprint: evaluation.interestFingerprint.isEmpty
            ? state.interestFingerprint
            : evaluation.interestFingerprint,
      );
      await _persist();
    } catch (error, stackTrace) {
      developer.log(
        'Could not evaluate navigation discovery for save $savedUrlId.',
        name: 'NavigationDiscovery',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> acknowledgeCollections() async {
    await _initialization;
    if (!state.hasNewCollections) return;
    state = state.copyWith(hasNewCollections: false);
    await _persist();
  }

  Future<void> acknowledgeInterests() async {
    await _initialization;
    if (!state.hasNewInterests) return;
    state = state.copyWith(hasNewInterests: false);
    await _persist();
  }

  Future<void> rebaselineAfterExternalDataChange() async {
    await _initialization;
    await _rebaseline(clearPending: true);
  }

  Future<void> resetAfterDataClear() async {
    await _initialization;
    state = NavigationDiscoveryState(
      isReady: true,
      libraryFingerprint: '811c9dc5',
      interestFingerprint: const InterestTopologySnapshot.empty().fingerprint,
    );
    await _persist();
  }

  Future<void> _rebaseline({required bool clearPending}) async {
    final urls = await _ref.read(navigationDiscoveryUrlsLoaderProvider)();
    final hiddenKeys = await _hiddenLibraryEntityKeys();
    final library = LibraryIndex.build(urls, hiddenKeys: hiddenKeys);
    final topology = await buildInterestTopologySnapshot(urls);
    state = NavigationDiscoveryState(
      isReady: true,
      hasNewCollections: clearPending ? false : state.hasNewCollections,
      hasNewInterests: clearPending ? false : state.hasNewInterests,
      libraryFingerprint: _fingerprintLibrary(library),
      interestFingerprint: topology.fingerprint,
    );
    await _persist();
  }

  Future<Set<String>> _hiddenLibraryEntityKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      ..._ref.read(libraryPreferencesProvider).hiddenEntityKeys,
      ...?prefs.getStringList(libraryHiddenEntityKeysPrefsKey),
    };
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      navigationDiscoveryPrefsKey,
      jsonEncode(state.toJson()),
    );
  }
}
