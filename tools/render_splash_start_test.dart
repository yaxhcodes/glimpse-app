import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/constants/app_assets.dart';
import 'package:glimpse/shared/widgets/startup_mascot.dart';

// Run before the Python asset exporter when the mascot or its motion changes.
void main() {
  testWidgets('export the exact Flutter starting pose for native splash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = ValueKey('splash-start');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(key: capture, child: StartupMascot(progress: 0)),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(AppAssets.homeHero),
        tester.element(find.byKey(capture)),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(capture),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'tools/icon_sources/mascot/splash_start.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
