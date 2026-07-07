import 'package:flutter/material.dart';

/// Keeps phone layouts visually stable when Android display size changes the
/// logical viewport behind Flutter's back.
class AppDisplayScale extends StatelessWidget {
  const AppDisplayScale({super.key, required this.child});

  static const double designPhoneWidth = 400;
  static const double minPhoneContentScale = 0.86;
  static const double maxPhoneTextScale = 1.12;

  final Widget child;

  @visibleForTesting
  static double contentScaleFor(
    MediaQueryData mediaQuery,
    TargetPlatform platform,
  ) {
    final size = mediaQuery.size;
    if (platform != TargetPlatform.android || size.shortestSide >= 600) {
      return 1;
    }
    if (size.width <= 0 || size.height <= 0) return 1;

    return (size.width / designPhoneWidth).clamp(minPhoneContentScale, 1.0);
  }

  @visibleForTesting
  static double textScaleFor(MediaQueryData mediaQuery) {
    final systemTextScale = mediaQuery.textScaler.scale(1);
    return systemTextScale > maxPhoneTextScale
        ? maxPhoneTextScale
        : systemTextScale;
  }

  @visibleForTesting
  static MediaQueryData normalizedMediaQuery(
    MediaQueryData mediaQuery,
    double contentScale,
  ) {
    final scale = contentScale <= 0 ? 1.0 : contentScale;
    final textScale = textScaleFor(mediaQuery);

    return mediaQuery.copyWith(
      size: mediaQuery.size / scale,
      devicePixelRatio: mediaQuery.devicePixelRatio * scale,
      padding: mediaQuery.padding / scale,
      viewPadding: mediaQuery.viewPadding / scale,
      viewInsets: mediaQuery.viewInsets / scale,
      systemGestureInsets: mediaQuery.systemGestureInsets / scale,
      textScaler: TextScaler.linear(textScale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final contentScale = contentScaleFor(
      mediaQuery,
      Theme.of(context).platform,
    );
    final normalized = normalizedMediaQuery(mediaQuery, contentScale);
    final hasTextScaleOverride =
        textScaleFor(mediaQuery) != mediaQuery.textScaler.scale(1);

    if (contentScale == 1 && !hasTextScaleOverride) {
      return child;
    }

    return SizedBox.expand(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: normalized.size.width,
          maxWidth: normalized.size.width,
          minHeight: normalized.size.height,
          maxHeight: normalized.size.height,
          child: Transform.scale(
            scale: contentScale,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: normalized.size.width,
              height: normalized.size.height,
              child: MediaQuery(data: normalized, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
