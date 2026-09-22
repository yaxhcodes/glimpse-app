import '../database/isar_service.dart';
import '../models/saved_url.dart';

class SavedNotesService {
  const SavedNotesService(this._isarService);

  final IsarService _isarService;

  Future<bool> updatePersonalNote(int urlId, String text) {
    final normalized = text.trim().isEmpty ? null : text.trimRight();
    return _isarService.mutateUrl(urlId, (url) {
      url.userNotes = normalized;
    });
  }

  Future<bool> appendPersonalNote(int urlId, String text) {
    final note = text.trim();
    if (note.isEmpty) return Future.value(false);
    return _isarService.mutateUrl(urlId, (url) {
      final existing = (url.userNotes ?? '').trimRight();
      if (existing == note || existing.endsWith('\n\n$note')) return;
      url.userNotes = existing.isEmpty ? note : '$existing\n\n$note';
    });
  }

  Future<bool> saveAskNote({
    required int urlId,
    required String sourceMessageId,
    required String question,
    required String body,
  }) {
    final normalizedQuestion = question.trim();
    final normalizedBody = body.trim();
    if (normalizedQuestion.isEmpty || normalizedBody.isEmpty) {
      return Future.value(false);
    }
    return _isarService.mutateUrl(urlId, (url) {
      final alreadySaved = url.askNotes.any(
        (note) => note.sourceMessageId == sourceMessageId,
      );
      if (alreadySaved) return;
      url.askNotes = [
        ...url.askNotes,
        SavedAskNote()
          ..id = 'ask_${urlId}_$sourceMessageId'
          ..sourceMessageId = sourceMessageId
          ..question = normalizedQuestion
          ..body = normalizedBody
          ..createdAt = DateTime.now(),
      ];
    });
  }

  Future<bool> deleteAskNote(int urlId, String noteId) {
    return _isarService.mutateUrl(urlId, (url) {
      url.askNotes = url.askNotes.where((note) => note.id != noteId).toList();
    });
  }
}
