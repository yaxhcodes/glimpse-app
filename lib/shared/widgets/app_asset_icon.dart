import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppAssetIcon extends StatelessWidget {
  const AppAssetIcon(
    this.asset, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final String asset;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final effectiveSize = size ?? theme.size ?? 24;
    final foreground =
        color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    // Keep the drawing independent of a prefix slot or badge's tight bounds.
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.asset(
        asset,
        width: effectiveSize,
        height: effectiveSize,
        colorFilter: ColorFilter.mode(
          foreground.withValues(alpha: foreground.a * (theme.opacity ?? 1)),
          BlendMode.srcIn,
        ),
        semanticsLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      ),
    );
  }
}
