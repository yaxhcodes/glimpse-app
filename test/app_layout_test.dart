import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/theme/app_layout.dart';

void main() {
  test('compact windows keep bottom navigation', () {
    expect(AppLayout.usesNavigationRail(599), isFalse);
  });

  test('medium and expanded windows use navigation rail', () {
    expect(AppLayout.usesNavigationRail(600), isTrue);
    expect(AppLayout.usesNavigationRail(1280), isTrue);
  });

  test('large windows use the labeled rail', () {
    expect(AppLayout.usesExtendedNavigationRail(1199), isFalse);
    expect(AppLayout.usesExtendedNavigationRail(1200), isTrue);
  });

  test('classifies all Material window width classes at their boundaries', () {
    expect(AppLayout.widthClass(599), AppWindowWidthClass.compact);
    expect(AppLayout.widthClass(600), AppWindowWidthClass.medium);
    expect(AppLayout.widthClass(839), AppWindowWidthClass.medium);
    expect(AppLayout.widthClass(840), AppWindowWidthClass.expanded);
    expect(AppLayout.widthClass(1199), AppWindowWidthClass.expanded);
    expect(AppLayout.widthClass(1200), AppWindowWidthClass.large);
    expect(AppLayout.widthClass(1599), AppWindowWidthClass.large);
    expect(AppLayout.widthClass(1600), AppWindowWidthClass.extraLarge);
  });

  test('readable pages center their content on wide windows', () {
    expect(AppLayout.pageHorizontalPadding(400), 16);
    expect(AppLayout.pageHorizontalPadding(1200), 220);
  });
}
