enum AppWindowWidthClass { compact, medium, expanded, large, extraLarge }

abstract final class AppLayout {
  /// Material compact-to-medium width boundary.
  static const double mediumWidth = 600;

  /// Material medium-to-expanded width boundary.
  static const double expandedWidth = 840;

  /// Material expanded-to-large width boundary.
  static const double largeWidth = 1200;

  /// Material large-to-extra-large width boundary.
  static const double extraLargeWidth = 1600;

  /// Prevents feeds and controls from stretching across desktop-size windows.
  static const double maxShellContentWidth = 1280;

  /// Comfortable reading width for settings, forms, and detail-like pages.
  static const double maxReadableContentWidth = 760;

  /// Editorial measure for long-form saved-item reading.
  static const double maxReaderContentWidth = 680;

  static bool usesNavigationRail(double width) => width >= mediumWidth;

  static bool usesExtendedNavigationRail(double width) => width >= largeWidth;

  static AppWindowWidthClass widthClass(double width) => switch (width) {
    < mediumWidth => AppWindowWidthClass.compact,
    < expandedWidth => AppWindowWidthClass.medium,
    < largeWidth => AppWindowWidthClass.expanded,
    < extraLargeWidth => AppWindowWidthClass.large,
    _ => AppWindowWidthClass.extraLarge,
  };

  static double pageHorizontalPadding(
    double width, {
    double compactPadding = 16,
    double maxContentWidth = maxReadableContentWidth,
  }) {
    final centeredPadding = (width - maxContentWidth) / 2;
    return centeredPadding > compactPadding ? centeredPadding : compactPadding;
  }
}
