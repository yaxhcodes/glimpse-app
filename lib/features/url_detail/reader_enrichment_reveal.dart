import 'package:flutter/material.dart';

/// How long each block of freshly enriched content takes to arrive, and how
/// far apart consecutive blocks start.
const kEnrichmentRevealBlock = Duration(milliseconds: 560);
const kEnrichmentRevealStagger = Duration(milliseconds: 90);

/// Blocks after this many start together, so a long page doesn't keep
/// trickling in.
const kEnrichmentRevealMaxStaggered = 7;

/// The whole reveal for [blockCount] blocks.
Duration enrichmentRevealDuration(int blockCount) {
  final staggered = (blockCount - 1).clamp(0, kEnrichmentRevealMaxStaggered);
  return kEnrichmentRevealStagger * staggered + kEnrichmentRevealBlock;
}

/// One block of content that arrived while the reader was on the page: it
/// opens up to its height, rises a little and emerges from the page's
/// surface, in turn with the blocks around it.
///
/// Cheap on every frame: the fade is a veil of the page's own surface colour
/// lifting off the block, not an opacity layer, and there is no blur. At
/// rest it adds nothing — no clip, no veil, no offset — and the child keeps
/// its state across the reveal.
class EnrichmentReveal extends StatelessWidget {
  const EnrichmentReveal({
    super.key,
    required this.animation,
    required this.order,
    required this.blockCount,
    required this.child,
  });

  final Animation<double> animation;
  final int order;
  final int blockCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = enrichmentRevealDuration(blockCount).inMicroseconds;
    final start =
        (kEnrichmentRevealStagger *
                order.clamp(0, kEnrichmentRevealMaxStaggered))
            .inMicroseconds /
        total;
    final end = start + kEnrichmentRevealBlock.inMicroseconds / total;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = ((animation.value - start) / (end - start)).clamp(0.0, 1.0);
        final rise = 1 - Curves.easeOutCubic.transform(t);
        final veil = 1 - Curves.easeOut.transform(t);
        final surface = Theme.of(context).colorScheme.surface;
        return ClipRect(
          clipBehavior: t < 1 ? Clip.hardEdge : Clip.none,
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: 1,
            heightFactor: Curves.easeInOutCubicEmphasized.transform(t),
            child: Transform.translate(
              offset: Offset(0, 16 * rise),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: veil <= 0
                    ? const BoxDecoration()
                    : BoxDecoration(
                        color: surface.withValues(alpha: surface.a * veil),
                      ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
