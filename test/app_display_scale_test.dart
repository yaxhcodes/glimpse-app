import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/app_display_scale.dart';

void main() {
  test('normalizes narrow Android phone viewports to the design canvas', () {
    const mediaQuery = MediaQueryData(
      size: Size(360, 800),
      devicePixelRatio: 3,
      padding: EdgeInsets.only(top: 24, bottom: 16),
    );

    final scale = AppDisplayScale.contentScaleFor(
      mediaQuery,
      TargetPlatform.android,
    );
    final normalized = AppDisplayScale.normalizedMediaQuery(mediaQuery, scale);

    expect(scale, closeTo(0.9, 0.001));
    expect(normalized.size.width, closeTo(400, 0.001));
    expect(normalized.size.height, closeTo(888.89, 0.01));
    expect(normalized.devicePixelRatio, closeTo(2.7, 0.001));
    expect(normalized.padding.top, closeTo(26.67, 0.01));
    expect(normalized.padding.bottom, closeTo(17.78, 0.01));
  });

  test('leaves Android tablets and other platforms at native scale', () {
    const tablet = MediaQueryData(size: Size(700, 1000));
    const phone = MediaQueryData(size: Size(360, 800));

    expect(AppDisplayScale.contentScaleFor(tablet, TargetPlatform.android), 1);
    expect(AppDisplayScale.contentScaleFor(phone, TargetPlatform.iOS), 1);
  });

  test('caps oversized text scaling without changing normal text scale', () {
    const normal = MediaQueryData(textScaler: TextScaler.linear(1));
    const oversized = MediaQueryData(textScaler: TextScaler.linear(1.4));

    expect(AppDisplayScale.textScaleFor(normal), 1);
    expect(
      AppDisplayScale.textScaleFor(oversized),
      AppDisplayScale.maxPhoneTextScale,
    );
  });
}
