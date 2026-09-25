import 'dart:convert';

import 'package:isar/isar.dart';

import '../database/isar_service.dart';
import '../models/ask_conversation.dart';

class AskConversationStore {
  const AskConversationStore(this.database);
  final IsarService database;

  Future<List<AskConversation>> list() async {
    final db = await database.database;
    return db.askConversations.where().sortByUpdatedAtDesc().findAll();
  }

  Future<void> save(AskConversation conversation) async {
    final db = await database.database;
    await db.writeTxn(() async {
      final existing = await db.askConversations.getByKey(conversation.key);
      if (existing != null) conversation.id = existing.id;
      await db.askConversations.put(conversation);
    });
  }

  Future<void> delete(int id) async {
    final db = await database.database;
    await db.writeTxn(() => db.askConversations.delete(id));
  }

  Future<List<Map<String, dynamic>>> export() async => [
    for (final chat in await list())
      {
        'key': chat.key,
        'title': chat.title,
        'version': chat.version,
        'createdAt': chat.createdAt.toIso8601String(),
        'updatedAt': chat.updatedAt.toIso8601String(),
        'focusedUrl': chat.focusedUrl,
        'messages': jsonDecode(chat.messagesJson),
      },
  ];

  Future<void> restore(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    final existing = {for (final chat in await list()) chat.key: chat};
    for (final record in records) {
      final key = record['key'];
      final messages = record['messages'];
      if (key is! String || messages is! List || record['version'] != 1) {
        continue;
      }
      final updatedAt = DateTime.tryParse(
        record['updatedAt']?.toString() ?? '',
      );
      if (updatedAt == null) continue;
      final previous = existing[key];
      if (previous != null && !updatedAt.isAfter(previous.updatedAt)) continue;
      final chat = AskConversation()
        ..id = previous?.id ?? Isar.autoIncrement
        ..key = key
        ..title = record['title']?.toString() ?? ''
        ..createdAt =
            DateTime.tryParse(record['createdAt']?.toString() ?? '') ??
            updatedAt
        ..updatedAt = updatedAt
        ..focusedUrl = record['focusedUrl'] as String?
        ..messagesJson = jsonEncode(messages);
      await save(chat);
    }
  }
}
