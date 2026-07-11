import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CreatorProfileLink extends StatelessWidget {
  const CreatorProfileLink({
    super.key,
    required this.username,
    required this.platform,
    this.accent,
    this.compact = false,
  });

  final String username;
  final String platform;
  final Color? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = username.replaceFirst('@', '').trim();
    if (normalized.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveAccent = accent ?? colorScheme.primary;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.alternate_email_rounded,
          size: compact ? 14 : 15,
          color: effectiveAccent.withValues(alpha: 0.82),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            normalized,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      color: effectiveAccent,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
          ),
        ),
        const SizedBox(width: 5),
        Icon(
          Icons.north_east_rounded,
          size: compact ? 13 : 15,
          color: effectiveAccent.withValues(alpha: 0.72),
        ),
      ],
    );

    final visual = compact
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(12),
            ),
            child: content,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: content,
          );

    return Semantics(
      link: true,
      label: 'Open $normalized on $platform',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 12 : 10),
            onTap: () => _openProfile(normalized),
            child: visual,
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
