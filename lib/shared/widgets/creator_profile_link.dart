import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CreatorProfileLink extends StatelessWidget {
  const CreatorProfileLink({
    super.key,
    required this.username,
    required this.platform,
  });

  final String username;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final normalized = username.replaceFirst('@', '').trim();
    if (normalized.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      link: true,
      label: 'Open $normalized on $platform',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openProfile(normalized),
            child: SizedBox(
              height: 32,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '@$normalized',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.88,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.north_east_rounded,
                    size: 13,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openProfile(String username) async {
    final lower = platform.toLowerCase();
    Uri? appUri;
    Uri webUri;
    if (lower.contains('instagram')) {
      appUri = Uri.parse('instagram://user?username=$username');
      webUri = Uri.https('instagram.com', '/$username');
    } else if (lower == 'x' || lower.contains('twitter')) {
      appUri = Uri.parse('twitter://user?screen_name=$username');
      webUri = Uri.https('x.com', '/$username');
    } else if (lower.contains('tiktok')) {
      webUri = Uri.https('www.tiktok.com', '/@$username');
    } else if (lower.contains('threads')) {
      webUri = Uri.https('www.threads.net', '/@$username');
    } else {
      webUri = Uri.https('www.google.com', '/search', {'q': username});
    }

    if (appUri != null) {
      try {
        if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // Fall back to the web profile below.
      }
    }
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
