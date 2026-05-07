import '../../core/services/link_preview_service.dart';

/// The lifecycle of a single URL inside a batch.
enum BatchItemStatus {
  pending,      // waiting to start
  fetching,     // fetching metadata
  ready,        // metadata fetched, ready to save
  duplicate,    // already exists in library
  error,        // metadata fetch failed
}

/// Immutable state for one URL in the batch preview.
class BatchUrlItem {
  final String rawUrl;
  final BatchItemStatus status;
  final LinkMetadata? metadata;
  final String? error;
  final bool isDuplicate;

  const BatchUrlItem({
    required this.rawUrl,
    this.status = BatchItemStatus.pending,
    this.metadata,
    this.error,
    this.isDuplicate = false,
  });

  BatchUrlItem copyWith({
    BatchItemStatus? status,
    LinkMetadata? metadata,
    String? error,
    bool? isDuplicate,
  }) {
    return BatchUrlItem(
      rawUrl: rawUrl,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      error: error ?? this.error,
      isDuplicate: isDuplicate ?? this.isDuplicate,
    );
  }

  String get displayTitle {
    if (metadata != null && metadata!.title.isNotEmpty) {
      return metadata!.title;
    }
    try {
      final host = Uri.parse(rawUrl).host;
      return host.isNotEmpty ? host : rawUrl;
    } catch (_) {
      return rawUrl;
    }
  }

  String get displayDomain {
    try {
      final host = Uri.parse(rawUrl).host.replaceFirst('www.', '');
      return host.isNotEmpty ? host : rawUrl;
    } catch (_) {
      return rawUrl;
    }
  }

  String? get thumbnailUrl => metadata?.imageUrl;
}
