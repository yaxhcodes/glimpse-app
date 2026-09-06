import 'package:flutter/material.dart';

import '../theme/app_shapes.dart';
import '../theme/topic_visual.dart';

class TopicEmblem extends StatelessWidget {
  const TopicEmblem({super.key, required this.visual, this.size = 48});

  final TopicVisual visual;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: visual.container(cs),
            shape: AppShapes.border(visual.shape),
          ),
          child: Icon(
            visual.icon,
            color: visual.foreground(cs),
            size: size * .48,
          ),
        ),
      ),
    );
  }
}
