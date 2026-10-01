import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/entitlement_service.dart';
import 'package:glimpse/core/services/vault/vault_crypto.dart';
import 'package:glimpse/core/services/vault/vault_repository.dart';
import 'package:glimpse/features/vault/vault_provider.dart';
import 'package:glimpse/features/vault/vault_screen.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boundaryKey = ValueKey('vault-golden-boundary');
const _seed = Color(0xFF6750A4);

class _FakeCrypto implements VaultCrypto {
  final bool screenLock = true;

  @override
  Future<VaultDeviceStatus> status() async =>
      VaultDeviceStatus(hasScreenLock: screenLock, keyInvalidated: false);

  @override
  Future<Uint8List> seal(Uint8List plain) async => plain;

  @override
  Future<VaultUnlockResult> unlock({
    required String title,
    String? subtitle,
    Uint8List? wrappedDataKey,
  }) async => const VaultUnlockResult(VaultUnlockStatus.ok);

  @override
  Future<List<Uint8List?>> open(List<Uint8List> sealed) async => sealed;

  @override
  Future<void> lock() async {}

  @override
  Future<void> reset() async {}

  VaultUnlockStatus confirmStatus = VaultUnlockStatus.ok;

  @override
  Future<VaultUnlockStatus> confirm({
    required String title,
    String? subtitle,
  }) async => confirmStatus;

  @override
  Future<void> setSecureScreen(bool secure) async {}
}

class _FakeRepository implements VaultRepository {
  _FakeRepository(this.entries, {this.unlockStatus = VaultUnlockStatus.ok});

  final List<VaultEntry> entries;
  final VaultUnlockStatus unlockStatus;
  final crypto = _FakeCrypto();

  @override
  Future<VaultDeviceStatus> deviceStatus() => crypto.status();

  @override
  Future<int> count() async => entries.length;

  @override
  Stream<void> watch() => Stream.value(null);

  @override
  Future<VaultUnlockResult> unlock({
    required String title,
    String? subtitle,
  }) async => VaultUnlockResult(unlockStatus);

  @override
  Future<VaultContents> openAll() async =>
      VaultContents(entries: entries, unreadable: 0);

  @override
  Future<void> lock() async {}

  @override
  Future<int> add({
    required String url,
    String? title,
    String? note,
    DateTime? savedAt,
  }) async => 0;

  @override
  Future<void> updateNote(VaultEntry entry, String? note) async {}

  @override
  Future<void> rewrite(int id, VaultPayload payload) async {}

  @override
  Future<void> rename(VaultEntry entry, String? title) async {}

  @override
  Future<void> delete(int id) async {}

  @override
  Future<int> moveIn(SavedUrl url, {required String title}) async => 0;

  @override
  Future<bool> confirmOwner({required String title, String? subtitle}) async =>
      true;

  @override
  Future<void> reset() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    for (final (family, asset) in [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ]) {
      await (FontLoader('packages/phosphor_flutter/$family')..addFont(
            rootBundle.load('packages/phosphor_flutter/lib/fonts/$asset'),
          ))
          .load();
    }
  });

  final entries = [
    VaultEntry(
      id: 3,
      url: 'https://www.instagram.com/reel/C9x2kLm',
      title: 'Anniversary dinner spots in Bandra',
      note: 'Book the rooftop one before the 14th',
      createdAt: DateTime(2026, 9, 28),
    ),
    VaultEntry(
      id: 2,
      url: 'https://youtu.be/8kTqP0v',
      title: 'Talking to your manager about a raise',
      createdAt: DateTime(2026, 9, 21),
    ),
    VaultEntry(
      id: 1,
      url: 'https://www.example-clinic.in/second-opinion',
      createdAt: DateTime(2026, 9, 2),
    ),
  ];

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Vault open $mode', (tester) async {
      await _pump(tester, dark: dark, repository: _FakeRepository(entries));
      expect(find.text('Anniversary dinner spots in Bandra'), findsOneWidget);
      await _expectGolden(tester, 'goldens/vault_open_$mode.png');
    });

    testWidgets('Vault locked $mode', (tester) async {
      await _pump(
        tester,
        dark: dark,
        repository: _FakeRepository(
          entries,
          unlockStatus: VaultUnlockStatus.cancelled,
        ),
      );
      expect(find.text('Your vault is locked'), findsOneWidget);
      await _expectGolden(tester, 'goldens/vault_locked_$mode.png');
    });
  }

  testWidgets('A long vault can be searched', (tester) async {
    final many = [
      ...entries,
      for (var i = 0; i < 6; i++)
        VaultEntry(
          id: 10 + i,
          url: 'https://example.com/item-$i',
          title: 'Saved thing $i',
          createdAt: DateTime(2026, 8, 20 - i),
        ),
    ];
    await _pump(tester, dark: false, repository: _FakeRepository(many));
    expect(find.text('Search your vault'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ROOFTOP');
    await tester.pumpAndSettle();
    expect(find.text('Anniversary dinner spots in Bandra'), findsOneWidget);
    expect(find.text('Saved thing 0'), findsNothing);
    await _expectGolden(tester, 'goldens/vault_search_light.png');

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text('Nothing in your vault matches'), findsOneWidget);
  });

  testWidgets('renaming and editing a note close cleanly', (tester) async {
    await _pump(tester, dark: false, repository: _FakeRepository(entries));

    await tester.tap(find.byTooltip('Item actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Dinner plans');
    await tester.tap(find.text('Save'));
    // Through the dialog's whole closing animation.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Dinner plans'), findsOneWidget);

    await tester.tap(find.byTooltip('Item actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Rooftop, 8pm');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Rooftop, 8pm'), findsOneWidget);
  });

  testWidgets('A short vault has no search', (tester) async {
    await _pump(tester, dark: false, repository: _FakeRepository(entries));
    expect(find.text('Search your vault'), findsNothing);
  });

  testWidgets('Vault Pro offer', (tester) async {
    await _pump(
      tester,
      dark: false,
      isPro: false,
      repository: _FakeRepository(const []),
    );
    expect(find.text('Vault is part of Glimpse Pro'), findsOneWidget);
    await _expectGolden(tester, 'goldens/vault_pro_offer_light.png');
  });

  testWidgets('Vault empty', (tester) async {
    await _pump(tester, dark: false, repository: _FakeRepository(const []));
    expect(find.text('Nothing in your vault yet'), findsOneWidget);
    await _expectGolden(tester, 'goldens/vault_empty_light.png');
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required bool dark,
  required VaultRepository repository,
  bool isPro = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultCryptoProvider.overrideWithValue(_FakeCrypto()),
        vaultRepositoryProvider.overrideWithValue(repository),
        isProUserProvider.overrideWithValue(isPro),
      ],
      child: RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(_seed),
          darkTheme: AppTheme.darkTheme(_seed),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const VaultScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(WidgetTester tester, String path) async {
  for (final element in tester.allElements) {
    element.renderObject?.markNeedsPaint();
  }
  await tester.pump();
  await expectLater(find.byKey(_boundaryKey), matchesGoldenFile(path));
}
