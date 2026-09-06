import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/material.dart';

/// A small vocabulary from MaterialShapes, shared by discovery surfaces.
enum AppShape { circle, cookie, clover, gem, arch, square }

abstract final class AppShapes {
  static final _borders = <AppShape, ShapeBorder>{};

  static ShapeBorder border(AppShape shape) => _borders.putIfAbsent(
    shape,
    () => RoundedPolygonBorder(
      polygon: switch (shape) {
        AppShape.circle => MaterialShapes.circle,
        AppShape.cookie => MaterialShapes.cookie6Sided,
        AppShape.clover => MaterialShapes.clover4Leaf,
        AppShape.gem => MaterialShapes.gem,
        AppShape.arch => MaterialShapes.arch,
        AppShape.square => MaterialShapes.square,
      },
    ),
  );
}
