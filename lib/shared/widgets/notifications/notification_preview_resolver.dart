import '../../../core/models/saved_url.dart';
import '../../../core/services/domain_categorizer.dart';
import '../../../core/services/saved_media_resolver.dart';

/// Widescreen (e.g. 16:9) vs square hero (e.g. X profile photos).
enum NotificationHeroShape { widescreen, square }

/// How to render a curated preview for a [SavedUrl] in notifications.
class NotificationPreviewSpec {
  const NotificationPreviewSpec({
    required this.visualMode,
    this.networkUrl,
    this.heroShape = NotificationHeroShape.widescreen,
    this.showVideoPlayBadge = false,
  });

  final NotificationVisualMode visualMode;
  final String? networkUrl;

  /// Only applies when [visualMode] is [NotificationVisualMode.networkImage].
  final NotificationHeroShape heroShape;
  final bool showVideoPlayBadge;

  static Map<String, String>? instagramCdnHeadersFor(String? imageUrl) {
    return SavedMediaResolver.imageHttpHeaders(imageUrl);
  }

  static NotificationPreviewSpec fromSavedUrl(SavedUrl url) {
    final platform = DomainCategorizer.categorize(url.rawUrl);
    final thumb = url.thumbnailUrl?.trim();
    final hasThumb = thumb != null && thumb.isNotEmpty;
    final host = Uri.tryParse(url.rawUrl)?.host.toLowerCase() ?? '';
    final path = Uri.tryParse(url.rawUrl)?.path.toLowerCase() ?? '';

    final isYoutube =
        platform.category == 'YouTube' || platform.category.contains('youtube');
    final isInstagram = platform.category == 'Instagram';
    final isX = platform.category == 'X';

    bool isTwitterAvatarThumb(String u) {
      final l = u.toLowerCase();
      return l.contains('unavatar.io/twitter') ||
          l.contains('unavatar.io/x.com') ||
          l.contains('pbs.twimg.com/profile_images') ||
          l.contains('/profile_images/');
    }

    bool isLikelyTweetMediaThumb(String u) {
      final l = u.toLowerCase();
      return l.contains('pbs.twimg.com/media') ||
          l.contains('pbs.twimg.com/amplify_video_thumb') ||
          l.contains('pbs.twimg.com/ext_tw_video_thumb');
    }

    final isIgLikelyVideo =
        host.contains('instagram') &&
        (path.contains('/reel') || path.contains('/tv/'));

    if (isX) {
      if (!hasThumb) {
        return const NotificationPreviewSpec(
          visualMode: NotificationVisualMode.neutralPlaceholder,
        );
      }
      final t = thumb;
      if (isLikelyTweetMediaThumb(t)) {
        return NotificationPreviewSpec(
          visualMode: NotificationVisualMode.networkImage,
          networkUrl: t,
          heroShape: NotificationHeroShape.widescreen,
        );
      }
      if (isTwitterAvatarThumb(t)) {
        return NotificationPreviewSpec(
          visualMode: NotificationVisualMode.networkImage,
          networkUrl: t,
          heroShape: NotificationHeroShape.square,
        );
      }
      return NotificationPreviewSpec(
        visualMode: NotificationVisualMode.networkImage,
        networkUrl: t,
        heroShape: NotificationHeroShape.widescreen,
      );
    }

    if (hasThumb && isInstagram) {
      return NotificationPreviewSpec(
        visualMode: NotificationVisualMode.networkImage,
        networkUrl: thumb,
        heroShape: NotificationHeroShape.square,
        showVideoPlayBadge: isIgLikelyVideo,
      );
    }

    if (hasThumb && isYoutube) {
      return NotificationPreviewSpec(
        visualMode: NotificationVisualMode.networkImage,
        networkUrl: thumb,
        heroShape: NotificationHeroShape.widescreen,
        showVideoPlayBadge: true,
      );
    }

    if (hasThumb) {
      return NotificationPreviewSpec(
        visualMode: NotificationVisualMode.networkImage,
        networkUrl: thumb,
        heroShape: NotificationHeroShape.widescreen,
        showVideoPlayBadge: isYoutube,
      );
    }

    return const NotificationPreviewSpec(
      visualMode: NotificationVisualMode.neutralPlaceholder,
    );
  }
}

enum NotificationVisualMode { networkImage, neutralPlaceholder }
