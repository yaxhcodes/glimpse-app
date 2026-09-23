import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_assets.dart';

/// Opens the Ask composer without submitting a question or spending quota.
class ReaderAskActions extends StatelessWidget {
  const ReaderAskActions({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onOpen,
      icon: SvgPicture.asset(
        AppAssets.brandMark,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          theme.colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
      label: Text(l10n.readerAskAbout),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
