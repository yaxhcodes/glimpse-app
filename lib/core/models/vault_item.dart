import 'package:isar/isar.dart';

part 'vault_item.g.dart';

/// One locked save. Its own collection, apart from [SavedUrl], so nothing
/// that reads saves — search, Rediscover, the Library, Ask, backups — can
/// ever see it.
///
/// Everything about the save lives in [sealed], encrypted by the Android
/// Keystore (see `VaultCrypto`). Only when it was filed is in the clear, so
/// the vault can count and order what it holds while locked.
@collection
class VaultItem {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime createdAt;

  /// The encrypted [VaultEntry]. The first byte is its sealed form: 1 was
  /// filed while the vault was locked, 2 under the open vault's key.
  List<byte> sealed = [];
}
