import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';

/// Shared by the running splash and the native first-frame export.
class StartupMascot extends StatelessWidget {
  const StartupMascot({super.key, required this.progress});

  final double progress;
  static const double size = 288 * 0.58;

  @override
  Widget build(BuildContext context) {
    final tucked =
        1 -
        const Interval(0, 0.65, curve: Curves.easeOutCubic).transform(progress);
    const artwork = Image(
      image: AssetImage(AppAssets.homeHero),
      fit: BoxFit.contain,
    );
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: const _MascotLayerClipper(card: false),
            child: Transform.translate(
              offset: Offset(0, constraints.maxHeight * (22 / size) * tucked),
              child: artwork,
            ),
          ),
          const ClipPath(
            clipper: _MascotLayerClipper(card: true),
            child: artwork,
          ),
        ],
      ),
    );
  }
}

/// The fixed card and hands follow the normalized contours of home.webp.
class _MascotLayerClipper extends CustomClipper<Path> {
  const _MascotLayerClipper({required this.card});
  final bool card;

  @override
  Path getClip(Size size) {
    final foreground = Path()
      ..moveTo(0, size.height * 0.58)
      ..lineTo(size.width, size.height * 0.66)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final hands = Path()
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.213,
          size.height * 0.538,
          size.width * 0.14,
          size.height * 0.1,
        ),
      )
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.66,
          size.height * 0.596,
          size.width * 0.14,
          size.height * 0.1,
        ),
      );
    final front = Path.combine(PathOperation.union, foreground, hands);
    return card
        ? front
        : Path.combine(
            PathOperation.difference,
            Path()..addRect(Offset.zero & size),
            front,
          );
  }

  @override
  bool shouldReclip(_MascotLayerClipper oldClipper) => oldClipper.card != card;
}
