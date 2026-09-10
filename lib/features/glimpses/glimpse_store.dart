import 'dart:convert';
import 'dart:developer' as developer;

import 'package:isar/isar.dart';

import '../../core/database/isar_service.dart';
import '../../core/models/glimpse_record.dart';
import 'glimpse.dart';

class StoredGlimpse {
  const StoredGlimpse(this.glimpse, this.record);
  final Glimpse glimpse;
  final GlimpseRecord record;

  bool visibleAt(DateTime now) =>
      record.retiredAt == null && !(record.snoozedUntil?.isAfter(now) ?? false);
}

class GlimpseStore {
  const GlimpseStore(this.isar);
  final IsarService isar;

  Future<List<StoredGlimpse>> load() async {
    final db = await isar.database;
    final records = await db.glimpseRecords.where().findAll();
    return records.map(decode).whereType<StoredGlimpse>().toList();
  }

  static StoredGlimpse? decode(GlimpseRecord record) {
    try {
      return StoredGlimpse(
        Glimpse.fromJson(
          Map<String, dynamic>.from(jsonDecode(record.contentJson) as Map),
        ),
        record,
      );
    } on Object catch (error, stack) {
      developer.log(
        'Unable to decode Glimpse record',
        name: 'GlimpseStore',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  Future<void> reconcile(List<Glimpse> candidates, DateTime now) async {
    final db = await isar.database;
    await db.writeTxn(() async {
      final existing = {
        for (final r in await db.glimpseRecords.where().findAll()) r.key: r,
      };
      final keys = <String>{};
      for (final glimpse in candidates) {
        keys.add(glimpse.key);
        final record =
            existing[glimpse.key] ?? (GlimpseRecord()..key = glimpse.key);
        final encoded = jsonEncode(glimpse.toJson());
        if (existing.containsKey(glimpse.key) &&
            record.contentJson == encoded) {
          continue;
        }
        final contentChanged =
            !existing.containsKey(glimpse.key) ||
            decode(record)?.glimpse.revision != glimpse.revision;
        record.contentJson = encoded;
        record.updatedAt = now;
        if (contentChanged) {
          record.synthesisJson = null;
          record.synthesisKey = null;
        }
        await db.glimpseRecords.put(record);
      }
      // Keep receipts for recently expired candidates, but never stale content
      // whose source has been deleted. The service supplies valid candidates.
      final stale = existing.values
          .where((r) => !keys.contains(r.key))
          .toList();
      for (final record in stale) {
        final old = decode(record)?.glimpse;
        if (old == null || now.difference(record.updatedAt).inDays > 365) {
          await db.glimpseRecords.delete(record.id);
        }
      }
    });
  }

  Future<void> mutate(String key, void Function(GlimpseRecord) change) async {
    final db = await isar.database;
    await db.writeTxn(() async {
      final record = await db.glimpseRecords
          .filter()
          .keyEqualTo(key)
          .findFirst();
      if (record == null) return;
      change(record);
      await db.glimpseRecords.put(record);
    });
  }

  Future<void> removeSources(Set<int> validIds) async {
    final db = await isar.database;
    await db.writeTxn(() async {
      final records = await db.glimpseRecords.where().findAll();
      final invalid = records
          .where((r) {
            final g = decode(r)?.glimpse;
            return g == null || g.sourceIds.any((id) => !validIds.contains(id));
          })
          .map((r) => r.id)
          .toList();
      await db.glimpseRecords.deleteAll(invalid);
    });
  }

  Stream<void> watch() async* {
    final db = await isar.database;
    yield* db.glimpseRecords.watchLazy();
  }

  /// Recheck the entire budget while holding the database write lock so two
  /// background workers cannot both spend the same delivery slot.
  Future<bool> claim(String key, DateTime now) async {
    final db = await isar.database;
    return db.writeTxn(() async {
      final records = await db.glimpseRecords.where().findAll();
      final all = records.map(decode).whereType<StoredGlimpse>().toList();
      final item = all.where((s) => s.glimpse.key == key).firstOrNull;
      if (item == null || !GlimpseDeliveryPolicy.canPost(item, all, now)) {
        return false;
      }
      item.record.deliveryLeaseUntil = now.add(const Duration(minutes: 10));
      await db.glimpseRecords.put(item.record);
      return true;
    });
  }
}

class GlimpseDeliveryPolicy {
  static bool isRequestedReturn(StoredGlimpse item, DateTime now) {
    final due = item.record.snoozedUntil;
    return due != null &&
        !due.isAfter(now) &&
        (item.record.reminderPostedAt == null ||
            item.record.reminderPostedAt!.isBefore(due));
  }

  static bool canPost(
    StoredGlimpse item,
    List<StoredGlimpse> all,
    DateTime now,
  ) {
    final g = item.glimpse;
    final requested = isRequestedReturn(item, now);
    if (now.hour < 9 ||
        now.hour >= 21 ||
        !item.visibleAt(now) ||
        !g.canNotify ||
        g.availableAt.isAfter(now) ||
        (!requested && !g.expiresAt.isAfter(now)) ||
        (!requested &&
            (item.record.postedAt != null || item.record.openedAt != null)) ||
        (item.record.deliveryLeaseUntil?.isAfter(now) ?? false)) {
      return false;
    }
    if (g.kind == GlimpseKind.weekly && now.weekday != DateTime.sunday) {
      return false;
    }
    if (all.any((s) => s.record.deliveryLeaseUntil?.isAfter(now) ?? false)) {
      return false;
    }
    if (g.isReminder || requested) {
      return !all.any((s) {
        final posted =
            s.record.reminderPostedAt ??
            (s.glimpse.isReminder ? s.record.postedAt : null);
        return posted != null &&
            now.difference(posted) < const Duration(hours: 20);
      });
    }
    final posted = all
        .where((s) => s.record.postedAt != null && !s.glimpse.isReminder)
        .toList();
    if (posted.any(
      (s) => now.difference(s.record.postedAt!) < const Duration(hours: 48),
    )) {
      return false;
    }
    if (posted
            .where(
              (s) =>
                  now.difference(s.record.postedAt!) < const Duration(days: 7),
            )
            .length >=
        3) {
      return false;
    }
    final sources = g.sourceIds.toSet();
    if (posted.any(
      (s) =>
          now.difference(s.record.postedAt!) < const Duration(days: 14) &&
          s.glimpse.sourceIds.any(sources.contains),
    )) {
      return false;
    }
    return true;
  }
}
