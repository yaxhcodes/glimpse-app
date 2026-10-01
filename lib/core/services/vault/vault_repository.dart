import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/isar_service.dart';
import '../../models/saved_url.dart';
import '../../models/vault_item.dart';
import 'vault_crypto.dart';

/// One vault item, opened.
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.url,
    required this.createdAt,
    this.title,
    this.note,
    this.savedAt,
  });

  final int id;
  final String url;
  final String? title;
  final String? note;

  /// When it went into the vault.
  final DateTime createdAt;

  /// When it was first saved, for items moved in from the saves.
  final DateTime? savedAt;

  String get host {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// The title if it has one, else the link without its scheme.
  String get displayTitle {
    final title = this.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    return url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
  }

  /// The same item with [title] and [note] as given (null clears either).
  VaultEntry edited({required String? title, required String? note}) =>
      VaultEntry(
        id: id,
        url: url,
        createdAt: createdAt,
        title: title,
        note: note,
        savedAt: savedAt,
      );

  /// Whether [query] (already lower-cased) appears in its name, note or
  /// link. Runs only over opened items, in memory: nothing is indexed.
  bool matches(String query) =>
      displayTitle.toLowerCase().contains(query) ||
      (note?.toLowerCase().contains(query) ?? false) ||
      url.toLowerCase().contains(query);
}

/// What the sealed bytes say. Kept short: it is stored once per item.
class VaultPayload {
  const VaultPayload({required this.url, this.title, this.note, this.savedAt});

  final String url;
  final String? title;
  final String? note;
  final DateTime? savedAt;

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'v': 1,
        'u': url,
        if (_present(title)) 't': title!.trim(),
        if (_present(note)) 'n': note!.trim(),
        if (savedAt != null) 's': savedAt!.toUtc().toIso8601String(),
      }),
    ),
  );

  static VaultPayload? decode(Uint8List bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic>) return null;
      final url = json['u'];
      if (url is! String || url.isEmpty) return null;
      final savedAt = json['s'];
      return VaultPayload(
        url: url,
        title: json['t'] as String?,
        note: json['n'] as String?,
        savedAt: savedAt is String
            ? DateTime.tryParse(savedAt)?.toLocal()
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _present(String? value) => (value?.trim() ?? '').isNotEmpty;
}

class VaultContents {
  const VaultContents({required this.entries, required this.unreadable});

  /// Newest first.
  final List<VaultEntry> entries;

  /// Items that couldn't be opened this time (left as they are).
  final int unreadable;
}

/// The vault's storage. Every read of what's inside goes through an
/// unlocked [VaultCrypto]; nothing here keeps opened items.
class VaultRepository {
  VaultRepository({
    required IsarService isarService,
    required VaultCrypto crypto,
  }) : _isarService = isarService,
       _crypto = crypto;

  final IsarService _isarService;
  final VaultCrypto _crypto;

  static const _wrappedKeyPref = 'vault_wrapped_data_key_v1';
  static const _tag = 'Vault';

  Future<Isar> get _db => _isarService.database;

  Future<VaultDeviceStatus> deviceStatus() => _crypto.status();

  Future<int> count() async => (await _db).vaultItems.count();

  Stream<void> watch() async* {
    final isar = await _db;
    yield* isar.vaultItems.watchLazy(fireImmediately: true);
  }

  /// Files a link. Works while locked.
  Future<int> add({
    required String url,
    String? title,
    String? note,
    DateTime? savedAt,
  }) async {
    final sealed = await _crypto.seal(
      VaultPayload(
        url: url,
        title: title,
        note: note,
        savedAt: savedAt,
      ).encode(),
    );
    final item = VaultItem()
      ..createdAt = DateTime.now()
      ..sealed = sealed;
    final isar = await _db;
    return isar.writeTxn(() => isar.vaultItems.put(item));
  }

  /// Seals [entry] again with its new [note].
  Future<void> updateNote(VaultEntry entry, String? note) => rewrite(
    entry.id,
    VaultPayload(
      url: entry.url,
      title: entry.title,
      note: note,
      savedAt: entry.savedAt,
    ),
  );

  /// Seals [entry] again under its new [title] (null shows the link).
  Future<void> rename(VaultEntry entry, String? title) => rewrite(
    entry.id,
    VaultPayload(
      url: entry.url,
      title: title,
      note: entry.note,
      savedAt: entry.savedAt,
    ),
  );

  /// Replaces what item [id] holds with [payload]. Works while locked.
  Future<void> rewrite(int id, VaultPayload payload) async {
    final isar = await _db;
    final item = await isar.vaultItems.get(id);
    if (item == null) return;
    item.sealed = await _crypto.seal(payload.encode());
    await isar.writeTxn(() => isar.vaultItems.put(item));
  }

  Future<VaultUnlockResult> unlock({
    required String title,
    String? subtitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_wrappedKeyPref);
    final result = await _crypto.unlock(
      title: title,
      subtitle: subtitle,
      wrappedDataKey: stored == null ? null : base64Decode(stored),
    );
    final fresh = result.wrappedDataKey;
    if (result.status == VaultUnlockStatus.ok && fresh != null) {
      await prefs.setString(_wrappedKeyPref, base64Encode(fresh));
    }
    return result;
  }

  /// Opens everything. Items filed while locked are sealed again under the
  /// open vault's key on the way, so the next unlock reads them faster.
  Future<VaultContents> openAll() async {
    final isar = await _db;
    final items = await isar.vaultItems.where().sortByCreatedAtDesc().findAll();
    final opened = await _crypto.open([
      for (final item in items) Uint8List.fromList(item.sealed),
    ]);
    final entries = <VaultEntry>[];
    final resealed = <VaultItem>[];
    var unreadable = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final bytes = i < opened.length ? opened[i] : null;
      final payload = bytes == null ? null : VaultPayload.decode(bytes);
      if (bytes == null || payload == null) {
        unreadable++;
        continue;
      }
      entries.add(
        VaultEntry(
          id: item.id,
          url: payload.url,
          title: payload.title,
          note: payload.note,
          savedAt: payload.savedAt,
          createdAt: item.createdAt,
        ),
      );
      if (item.sealed.isNotEmpty && item.sealed.first == 1) {
        try {
          item.sealed = await _crypto.seal(bytes);
          resealed.add(item);
        } catch (error) {
          developer.log(
            'Could not reseal a vault item',
            name: _tag,
            error: error,
          );
        }
      }
    }
    if (resealed.isNotEmpty) {
      await isar.writeTxn(() => isar.vaultItems.putAll(resealed));
    }
    return VaultContents(entries: entries, unreadable: unreadable);
  }

  Future<void> lock() => _crypto.lock();

  Future<void> delete(int id) async {
    final isar = await _db;
    await isar.writeTxn(() => isar.vaultItems.delete(id));
  }

  /// Moves a save into the vault: sealed first, then removed from the saves
  /// for good (not to the Bin, which would leave a copy in the open).
  Future<int> moveIn(SavedUrl url, {required String title}) async {
    final id = await add(
      url: url.rawUrl,
      title: title,
      note: url.userNotes,
      savedAt: url.savedAt,
    );
    await _isarService.deleteUrlsPermanently([url.id]);
    return id;
  }

  /// Whether the person holding the phone is its owner. A phone with no
  /// screen lock has nothing to ask with, and nothing left to protect.
  Future<bool> confirmOwner({required String title, String? subtitle}) async {
    final status = await _crypto.confirm(title: title, subtitle: subtitle);
    return status == VaultUnlockStatus.ok ||
        status == VaultUnlockStatus.noScreenLock;
  }

  /// Empties the vault and destroys its key. Can't be undone, so callers
  /// go through [confirmOwner] first.
  Future<void> reset() async {
    await _crypto.reset();
    final isar = await _db;
    await isar.writeTxn(() => isar.vaultItems.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wrappedKeyPref);
  }
}
