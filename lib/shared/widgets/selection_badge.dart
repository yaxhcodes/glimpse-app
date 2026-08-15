import 'package:flutter/material.dart';

class SelectionBadge extends StatelessWidget {
  const SelectionBadge({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      key: ValueKey(selected ? 'selection-selected' : 'selection-unselected'),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colorScheme.primary : colorScheme.surface,
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.outline,
          width: selected ? 0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 18, color: colorScheme.onPrimary)
          : null,
    );
  }
}
