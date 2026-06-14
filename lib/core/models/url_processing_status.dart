class UrlProcessingStatus {
  static const pending = 'PENDING';
  static const queued = 'QUEUED';
  static const extracting = 'EXTRACTING';
  static const transcriptReady = 'TRANSCRIPT_READY';
  static const enriching = 'ENRICHING';
  static const generatingRecommendations = 'GENERATING_RECOMMENDATIONS';
  static const generatingEmbeddings = 'GENERATING_EMBEDDINGS';
  static const ready = 'READY';
  static const failed = 'FAILED';
  static const retrying = 'RETRYING';

  static bool isActive(String? status) {
    return status == pending ||
        status == queued ||
        status == extracting ||
        status == transcriptReady ||
        status == enriching ||
        status == generatingRecommendations ||
        status == generatingEmbeddings ||
        status == retrying;
  }
}
