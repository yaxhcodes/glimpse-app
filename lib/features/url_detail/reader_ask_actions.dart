import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';

/// Opens the Ask composer without submitting a question or spending quota.
class ReaderAskActions extends StatelessWidget {
  const ReaderAskActions({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextButton.icon(
      onPressed: onOpen,
      icon: Icon(AppIcons.sparkle, size: 20),
      label: Text(l10n.readerAskAbout),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
