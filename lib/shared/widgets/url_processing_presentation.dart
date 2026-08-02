import '../../core/models/url_processing_status.dart';

class UrlProcessingPresentation {
  const UrlProcessingPresentation({
    required this.headline,
    required this.detail,
    this.failed = false,
  });

  final String headline;
  final String detail;
  final bool failed;

  factory UrlProcessingPresentation.fromStatus(
    String? status, {
    required String sourceName,
  }) {
    switch (status?.trim().toUpperCase()) {
      case UrlProcessingStatus.pending:
      case UrlProcessingStatus.queued:
        return const UrlProcessingPresentation(
          headline: 'Saved to your library',
          detail: 'Waiting to understand your save',
        );
      case UrlProcessingStatus.processing:
        return const UrlProcessingPresentation(
          headline: 'Opening the content',
          detail: 'Checking what this save contains',
        );
      case UrlProcessingStatus.extracting:
        return UrlProcessingPresentation(
          headline: 'Reading the ${_contentNoun(sourceName)}',
          detail: 'Pulling out the useful details',
        );
      case UrlProcessingStatus.transcriptReady:
        return const UrlProcessingPresentation(
          headline: 'Content understood',
          detail: 'Turning content into a useful save',
        );
      case UrlProcessingStatus.enriching:
        return const UrlProcessingPresentation(
          headline: 'Finding what matters',
          detail: 'Finding the ideas that matter most',
        );
      case UrlProcessingStatus.generatingRecommendations:
        return const UrlProcessingPresentation(
          headline: 'Connecting the dots',
          detail: 'Connecting this with related saves',
        );
      case UrlProcessingStatus.generatingEmbeddings:
        return const UrlProcessingPresentation(
          headline: 'Finishing your save',
          detail: 'Finishing search and rediscovery',
        );
      case UrlProcessingStatus.retrying:
        return const UrlProcessingPresentation(
          headline: 'Trying that step again',
          detail: 'Trying this processing step again',
        );
      case UrlProcessingStatus.failed:
      case UrlProcessingStatus.partial:
        return const UrlProcessingPresentation(
          headline: 'Couldn\'t finish processing',
          detail: 'Your save is safe. Try processing again',
          failed: true,
        );
      default:
        return const UrlProcessingPresentation(
          headline: 'Understanding this save',
          detail: 'Finding the ideas worth keeping',
        );
    }
  }

  static String _contentNoun(String sourceName) {
    switch (sourceName.trim().toLowerCase()) {
      case 'instagram':
        return 'reel';
      case 'youtube':
      case 'tiktok':
        return 'video';
      case 'pinterest':
        return 'pin';
      default:
        return 'page';
    }
  }
}
