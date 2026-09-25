import 'package:flutter/widgets.dart';

/// Physical pixel size to decode a network image at, for a widget that is
/// [logicalSize] logical pixels on its longest displayed edge.
///
/// List thumbnails are tiny compared with the og:image behind them (often
/// 1200px wide). Decoding at display size keeps scrolling smooth and cuts the
/// image cache's memory use; [headroom] leaves room for cover-cropping images
/// whose aspect ratio differs from the slot.
int imageDecodeSize(
  BuildContext context,
  double logicalSize, {
  double headroom = 1.0,
}) {
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;
  return (logicalSize * dpr * headroom).ceil().clamp(1, 4096);
}
