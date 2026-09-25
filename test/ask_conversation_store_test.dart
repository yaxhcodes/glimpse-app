import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/core/providers/usage_providers.dart';
import 'package:glimpse/features/ask/ask_provider.dart';
import 'ask_library_context_test.dart' show save;
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/engagement_event.dart';
import 'package:glimpse/core/models/glimpse_record.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/models/ask_conversation.dart';
import 'package:glimpse/core/services/ask_conversation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Isar database;
  late IsarService isar;
  late AskConversationStore store;

  setUpAll(() async {
    final cache =
        Platform.environment['PUB_CACHE'] ??
        (Platform.isWindows
            ? '${Platform.environment['LOCALAPPDATA']}/Pub/Cache'
            : '${Platform.environment['HOME']}/.pub-cache');
    final package = '$cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1';
    final library = Platform.isWindows
        ? '$package/windows/isar.dll'
        : Platform.isMacOS
        ? '$package/macos/libisar.dylib'
        : '$package/linux/libisar.so';
    await Isar.initializeIsarCore(libraries: {Abi.current(): library});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('glimpse-engine-test-');
    database = await Isar.open([
      SavedUrlSchema,
      AskConversationSchema,
      UserCollectionSchema,
      EngagementEventSchema,
      GlimpseRecordSchema,
    ], directory: directory.path);
    isar = IsarService();
    await isar.ensureInitialized();
    store = AskConversationStore(isar);
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  test('conversation history survives reopen and backup restore', () async {
    final chat = AskConversation()
      ..key = 'chat-1'
      ..title = 'Why this matters'
      ..createdAt = DateTime(2026)
      ..updatedAt = DateTime(2026, 9)
      ..focusedUrl = 'https://example.com/source'
      ..messagesJson =
          '[{"id":"turn-1","text":"Evidence [1]","isUser":false,"sources":["https://example.com/source"]}]';
    await store.save(chat);
    final backup = await store.export();
    expect(backup.single['messages'], isA<List>());
    await store.delete((await store.list()).single.id);
    expect(await store.list(), isEmpty);
    await store.restore(backup);
    final restored = (await store.list()).single;
    expect(restored.focusedUrl, chat.focusedUrl);
    expect(restored.messagesJson, contains('https://example.com/source'));
    await store.restore(backup);
    expect(await store.list(), hasLength(1));
    await database.close();
    database = await Isar.open([
      SavedUrlSchema,
      AskConversationSchema,
      UserCollectionSchema,
      EngagementEventSchema,
      GlimpseRecordSchema,
    ], directory: directory.path);
    isar = IsarService();
    await isar.ensureInitialized();
    store = AskConversationStore(isar);
    expect(await store.list(), hasLength(1));
  });

  test(
    'Ask answers 437 locally without touching AI, connectivity, or quota',
    () async {
      final saves = List.generate(437, (i) => save(i + 1));
      saves.first.intentStatus = 'done';
      final binned = save(1000)..deletedAt = DateTime(2026);
      await database.writeTxn(
        () => database.savedUrls.putAll([...saves, binned]),
      );
      final container = ProviderContainer(
        overrides: [
          isarServiceProvider.overrideWithValue(isar),
          usageServiceProvider.overrideWith(
            (ref) => throw StateError('Quota must not be read'),
          ),
          networkStatusServiceProvider.overrideWith(
            (ref) => throw StateError('Connectivity must not be read'),
          ),
          geminiServiceProvider.overrideWith(
            (ref) => throw StateError('AI must not be read'),
          ),
        ],
      );
      final notifier = container.read(askProvider.notifier);
      await notifier.ask('how many links do we have?');
      expect(container.read(askProvider).messages.last.text, contains('437'));
      expect(container.read(askProvider).isLoading, isFalse);
      final chats = await notifier.conversations();
      expect(chats, hasLength(1));
      await notifier.deleteConversation(chats.single);
      expect(await store.list(), isEmpty);
      container.dispose();
      await notifier.conversations();
    },
  );

  test('unsupported conversation versions are not imported', () async {
    await store.restore([
      {
        'key': 'unknown',
        'version': 999,
        'messages': [],
        'updatedAt': '2026-09-24',
      },
    ]);
    expect(await store.list(), isEmpty);
  });
}
