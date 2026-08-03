import '../models/saved_url.dart';

class SavedNotesCodec {
  SavedNotesCodec._();

  static final RegExp _legacyHeader = RegExp(
    r'^## Ask Glimpse\s*$',
    multiLine: true,
  );

  /// Moves well-formed legacy Ask blocks out of [SavedUrl.userNotes].
  /// Malformed blocks stay byte-for-byte in the personal note so migration can
  /// never discard content it does not understand.
  static bool migrateLegacyAskNotes(SavedUrl url) {
    final raw = url.userNotes ?? '';
    final headers = _legacyHeader.allMatches(raw).toList();
    if (headers.isEmpty) return false;

    final preserved = StringBuffer();
    var cursor = 0;
    var changed = false;
    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      preserved.write(raw.substring(cursor, header.start));
      final end = index + 1 < headers.length
          ? headers[index + 1].start
          : raw.length;
      final block = raw.substring(header.start, end);
      final parsed = _parseLegacyBlock(block);
      if (parsed == null) {
        preserved.write(block);
      } else {
        _addIfMissing(url.askNotes, parsed);
        changed = true;
      }
      cursor = end;
    }
    if (!changed) return false;

    url.userNotes = _trimPreservedNote(preserved.toString());
    return true;
  }

  static List<SavedAskNote> mergeAskNotes(
    Iterable<SavedAskNote> existing,
    Iterable<SavedAskNote> incoming,
  ) {
    final merged = existing.map(copyAskNote).toList();
    for (final note in incoming) {
      _addIfMissing(merged, copyAskNote(note));
    }
    return merged;
  }

  static SavedAskNote copyAskNote(SavedAskNote source) => SavedAskNote()
    ..id = source.id
    ..sourceMessageId = source.sourceMessageId
    ..question = source.question
    ..body = source.body
    ..createdAt = source.createdAt;

  static SavedAskNote? _parseLegacyBlock(String block) {
    final lines = block.split('\n');
    if (lines.isEmpty || lines.first.trim() != '## Ask Glimpse') return null;

    String? asked;
    String? question;
    final bodyLines = <String>[];
    for (final rawLine in lines.skip(1)) {
      final line = rawLine.trimRight();
      if (line.startsWith('Asked:')) {
        asked = line.substring('Asked:'.length).trim();
      } else if (line.startsWith('Question:')) {
        question = line.substring('Question:'.length).trim();
      } else {
        bodyLines.add(line);
      }
    }
    final body = bodyLines.join('\n').trim();
    if ((question ?? '').isEmpty || body.isEmpty) return null;

    final fingerprint = '$asked\n$question\n$body';
    return SavedAskNote()
      ..id = 'legacy_${_stableHash(fingerprint)}'
      ..question = question!
      ..body = body
      ..createdAt = _parseLegacyDate(asked);
  }

  static DateTime? _parseLegacyDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  static String? _trimPreservedNote(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static void _addIfMissing(List<SavedAskNote> notes, SavedAskNote candidate) {
    final duplicate = notes.any(
      (note) =>
          note.id == candidate.id ||
          (candidate.sourceMessageId != null &&
              note.sourceMessageId == candidate.sourceMessageId),
    );
    if (!duplicate) notes.add(candidate);
  }

  static String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
