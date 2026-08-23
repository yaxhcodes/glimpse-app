import '../../core/models/url_processing_status.dart';
import '../../l10n/l10n.dart';

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
    required AppLocalizations strings,
  }) {
    switch (status?.trim().toUpperCase()) {
      case UrlProcessingStatus.pending:
      case UrlProcessingStatus.queued:
        return UrlProcessingPresentation(
          headline: strings.processingSavedHeadline,
          detail: strings.processingSavedDetail,
        );
      case UrlProcessingStatus.processing:
        return UrlProcessingPresentation(
          headline: strings.processingOpeningHeadline,
          detail: strings.processingOpeningDetail,
        );
      case UrlProcessingStatus.extracting:
        return UrlProcessingPresentation(
          headline: strings.processingReadingHeadline(
            _contentNoun(sourceName, strings),
          ),
          detail: strings.processingExtractingDetail,
        );
      case UrlProcessingStatus.transcriptReady:
        return UrlProcessingPresentation(
          headline: strings.processingUnderstoodHeadline,
          detail: strings.processingUnderstoodDetail,
        );
      case UrlProcessingStatus.enriching:
        return UrlProcessingPresentation(
          headline: strings.processingFindingHeadline,
          detail: strings.processingFindingDetail,
        );
      case UrlProcessingStatus.generatingRecommendations:
        return UrlProcessingPresentation(
          headline: strings.processingConnectingHeadline,
          detail: strings.processingConnectingDetail,
        );
      case UrlProcessingStatus.generatingEmbeddings:
        return UrlProcessingPresentation(
          headline: strings.processingFinishingHeadline,
          detail: strings.processingFinishingDetail,
        );
      case UrlProcessingStatus.retrying:
        return UrlProcessingPresentation(
          headline: strings.processingRetryHeadline,
          detail: strings.processingRetryDetail,
        );
      case UrlProcessingStatus.failed:
      case UrlProcessingStatus.partial:
        return UrlProcessingPresentation(
          headline: strings.processingFailedHeadline,
          detail: strings.processingFailedDetail,
          failed: true,
        );
      default:
        return UrlProcessingPresentation(
          headline: strings.processingDefaultHeadline,
          detail: strings.processingDefaultDetail,
        );
    }
  }

  static String _contentNoun(String sourceName, AppLocalizations strings) {
    switch (sourceName.trim().toLowerCase()) {
      case 'instagram':
        return strings.processingContentReel;
      case 'youtube':
      case 'tiktok':
        return strings.processingContentVideo;
      case 'pinterest':
        return strings.processingContentPin;
      default:
        return strings.processingContentPage;
    }
  }
}
