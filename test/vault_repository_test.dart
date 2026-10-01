import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/ask_conversation.dart';
import 'package:glimpse/core/models/engagement_event.dart';
import 'package:glimpse/core/models/glimpse_record.dart';
import 'package:glimpse/core/models/place_itinerary.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/models/vault_item.dart';
import 'package:glimpse/core/services/vault/vault_crypto.dart';
import 'package:glimpse/core/services/vault/vault_repository.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the Keystore: "seals" by reversing the bytes behind a
/// version byte (1 while locked, 2 while open), and opens only while open.
class _FakeVaultCrypto implements VaultCrypto {
  bool unlocked = false;
  bool screenLock = true;
  bool invalidated = false;
  bool resetCalled = false;
  final Set<int> unreadableIndexes = {};

  @override
  Future<VaultDeviceStatus> status() async =>
      VaultDeviceStatus(hasScreenLock: screenLock, keyInvalidated: invalidated);

  @override
  Future<Uint8List> seal(Uint8List plain) async {
    if (!screenLock) throw const VaultCryptoException('no_screen_lock');
    return Uint8List.fromList([unlocked ? 2 : 1, ...plain.reversed]);
  }

  @override
  Future<VaultUnlockResult> unlock({
    required String title,
    String? subtitle,
    Uint8List? wrappedDataKey,
  }) async {
    unlocked = true;
    return VaultUnlockResult(
      VaultUnlockStatus.ok,
      wrappedDataKey: wrappedDataKey == null ? Uint8List.fromList([7]) : null,
    );
  }

  @override
  Future<List<Uint8List?>> open(List<Uint8List> sealed) async {
    if (!unlocked) throw const VaultCryptoException('locked');
    return [
      for (var i = 0; i < sealed.length; i++)
        unreadableIndexes.contains(i)
            ? null
            : Uint8List.fromList(sealed[i].sublist(1).reversed.toList()),
    ];
  }

  @override
  Future<void> lock() async => unlocked = false;

  @override
  Future<void> reset() async {
    resetCalled = true;
    unlocked = false;
  }

  VaultUnlockStatus confirmStatus = VaultUnlockStatus.ok;

  @override
  Future<VaultUnlockStatus> confirm({
    required String title,
    String? subtitle,
  }) async => confirmStatus;

  @override
  Future<void> setSecureScreen(bool secure) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Isar database;
  late IsarService isarService;
  late _FakeVaultCrypto crypto;
  late VaultRepository repository;

  setUpAll(() async {
    final pubCache =
        Platform.environment['PUB_CACHE'] ??
        (Platform.isWindows
            ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache'
            : '${Platform.environment['HOME']}/.pub-cache');
    final packageRoot =
        '$pubCache${Platform.pathSeparator}hosted${Platform.pathSeparator}pub.dev'
        '${Platform.pathSeparator}isar_flutter_libs-3.1.0+1';
    final libraryPath = Platform.isWindows
        ? '$packageRoot${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll'
        : Platform.isMacOS
        ? '$packageRoot${Platform.pathSeparator}macos${Platform.pathSeparator}libisar.dylib'
        : '$packageRoot${Platform.pathSeparator}linux${Platform.pathSeparator}libisar.so';
    await Isar.initializeIsarCore(libraries: {Abi.current(): libraryPath});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('glimpse-vault-');
    database = await Isar.open([
      SavedUrlSchema,
      AskConversationSchema,
      GlimpseRecordSchema,
      UserCollectionSchema,
      EngagementEventSchema,
      PlaceItinerarySchema,
      VaultItemSchema,
    ], directory: tempDirectory.path);
    isarService = IsarService();
    await isarService.ensureInitialized();
    crypto = _FakeVaultCrypto();
    repository = VaultRepository(isarService: isarService, crypto: crypto);
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'a link filed while locked is stored sealed, never in the clear',
    () async {
      await repository.add(url: 'https://example.com/secret', note: 'gift');

      final stored = await database.vaultItems.where().findAll();
      expect(stored, hasLength(1));
      expect(stored.single.sealed.first, 1);
      final raw = utf8.decode(stored.single.sealed, allowMalformed: true);
      expect(raw, isNot(contains('example.com')));
      expect(raw, isNot(contains('gift')));
      expect(await repository.count(), 1);
    },
  );

  test('opening needs an unlock first', () async {
    await repository.add(url: 'https://example.com/a');
    expect(repository.openAll(), throwsA(isA<VaultCryptoException>()));
  });

  test('unlocking opens newest first and reseals locked filings', () async {
    await repository.add(url: 'https://example.com/old');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repository.add(url: 'https://example.com/new', title: 'New one');

    final result = await repository.unlock(title: 'Unlock');
    expect(result.status, VaultUnlockStatus.ok);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vault_wrapped_data_key_v1'), isNotNull);

    final contents = await repository.openAll();
    expect(contents.unreadable, 0);
    expect(contents.entries.map((e) => e.url), [
      'https://example.com/new',
      'https://example.com/old',
    ]);
    expect(contents.entries.first.displayTitle, 'New one');
    expect(contents.entries.last.displayTitle, 'example.com/old');

    final stored = await database.vaultItems.where().findAll();
    expect(stored.every((item) => item.sealed.first == 2), isTrue);
  });

  test('items that cannot be opened are counted, not dropped', () async {
    await repository.add(url: 'https://example.com/a');
    await repository.add(url: 'https://example.com/b');
    crypto.unreadableIndexes.add(0);
    await repository.unlock(title: 'Unlock');

    final contents = await repository.openAll();
    expect(contents.entries, hasLength(1));
    expect(contents.unreadable, 1);
    expect(await repository.count(), 2);
  });

  test('moving a save in seals it and removes the save for good', () async {
    final saved = SavedUrl()
      ..rawUrl = 'https://www.instagram.com/reel/abc'
      ..domain = 'instagram.com'
      ..title = 'Saved link'
      ..description = ''
      ..category = 'Other'
      ..categoryEmoji = 'O'
      ..categories = ['Other']
      ..tags = []
      ..userNotes = 'for later'
      ..savedAt = DateTime.utc(2026, 3, 4);
    await database.writeTxn(() => database.savedUrls.put(saved));

    await repository.moveIn(saved, title: 'Anniversary ideas');

    expect(await database.savedUrls.get(saved.id), isNull);
    await repository.unlock(title: 'Unlock');
    final entry = (await repository.openAll()).entries.single;
    expect(entry.url, 'https://www.instagram.com/reel/abc');
    expect(entry.title, 'Anniversary ideas');
    expect(entry.note, 'for later');
    expect(entry.savedAt, DateTime.utc(2026, 3, 4).toLocal());
    expect(entry.host, 'instagram.com');
  });

  test('a note can be changed while locked', () async {
    final id = await repository.add(url: 'https://example.com/a');
    await repository.rewrite(
      id,
      const VaultPayload(url: 'https://example.com/a', note: 'added later'),
    );
    await repository.unlock(title: 'Unlock');
    expect((await repository.openAll()).entries.single.note, 'added later');
  });

  test(
    'renaming keeps the note, and clearing the name shows the link',
    () async {
      await repository.add(url: 'https://example.com/a', note: 'keep me');
      await repository.unlock(title: 'Unlock');
      final entry = (await repository.openAll()).entries.single;

      await repository.rename(entry, 'Second opinion');
      final renamed = (await repository.openAll()).entries.single;
      expect(renamed.displayTitle, 'Second opinion');
      expect(renamed.note, 'keep me');

      await repository.rename(renamed, null);
      expect(
        (await repository.openAll()).entries.single.displayTitle,
        'example.com/a',
      );
    },
  );

  test('search matches name, note and link, ignoring case', () {
    final entry = VaultEntry(
      id: 1,
      url: 'https://www.instagram.com/reel/C9x2kLm',
      title: 'Anniversary dinner spots',
      note: 'Book the rooftop one',
      createdAt: DateTime(2026),
    );
    expect(entry.matches('dinner'), isTrue);
    expect(entry.matches('rooftop'), isTrue);
    expect(entry.matches('instagram'), isTrue);
    expect(entry.matches('anniversary'), isTrue);
    expect(entry.matches('youtube'), isFalse);
  });

  test('only the phone owner can confirm a reset', () async {
    crypto.confirmStatus = VaultUnlockStatus.cancelled;
    expect(await repository.confirmOwner(title: 'Reset'), isFalse);
    crypto.confirmStatus = VaultUnlockStatus.failed;
    expect(await repository.confirmOwner(title: 'Reset'), isFalse);
    crypto.confirmStatus = VaultUnlockStatus.ok;
    expect(await repository.confirmOwner(title: 'Reset'), isTrue);
    // No screen lock: nothing to ask with, and nothing left to open.
    crypto.confirmStatus = VaultUnlockStatus.noScreenLock;
    expect(await repository.confirmOwner(title: 'Reset'), isTrue);
  });

  test('resetting empties the vault and forgets its key', () async {
    await repository.add(url: 'https://example.com/a');
    await repository.unlock(title: 'Unlock');

    await repository.reset();

    expect(crypto.resetCalled, isTrue);
    expect(await repository.count(), 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vault_wrapped_data_key_v1'), isNull);
  });

  test('filing fails loudly without a screen lock', () async {
    crypto.screenLock = false;
    expect(
      repository.add(url: 'https://example.com/a'),
      throwsA(
        isA<VaultCryptoException>().having(
          (e) => e.code,
          'code',
          'no_screen_lock',
        ),
      ),
    );
  });

  group('VaultPayload', () {
    test('round-trips, dropping empty fields', () {
      final payload = VaultPayload(
        url: 'https://example.com',
        title: '  Title ',
        note: '   ',
        savedAt: DateTime.utc(2026, 1, 2),
      );
      final json = jsonDecode(utf8.decode(payload.encode())) as Map;
      expect(json.containsKey('n'), isFalse);

      final decoded = VaultPayload.decode(payload.encode())!;
      expect(decoded.url, 'https://example.com');
      expect(decoded.title, 'Title');
      expect(decoded.note, isNull);
      expect(decoded.savedAt, DateTime.utc(2026, 1, 2).toLocal());
    });

    test('rejects bytes that are not a payload', () {
      expect(VaultPayload.decode(Uint8List.fromList([1, 2, 3])), isNull);
      expect(
        VaultPayload.decode(Uint8List.fromList(utf8.encode('{"t":"x"}'))),
        isNull,
      );
    });
  });
}
