import 'package:flutter/material.dart';

/// A navigation icon with a calm, non-numeric discovery indicator.
class NavigationDiscoveryIcon extends StatelessWidget {
  const NavigationDiscoveryIcon({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    required this.discoveryLabel,
    this.showBadge = false,
  });

  final Widget icon;
  final String semanticsLabel;
  final String discoveryLabel;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: showBadge ? '$semanticsLabel, $discoveryLabel' : semanticsLabel,
      excludeSemantics: true,
      child: Badge(
        backgroundColor: Theme.of(context).colorScheme.primary,
        smallSize: 7,
        isLabelVisible: showBadge,
        child: icon,
      ),
    );
  }
}
