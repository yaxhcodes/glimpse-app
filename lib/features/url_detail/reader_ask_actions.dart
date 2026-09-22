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
    return FilledButton.tonalIcon(
      onPressed: onOpen,
      icon: SvgPicture.asset(
        AppAssets.brandMark,
        width: 26,
        height: 26,
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onSecondaryContainer,
          BlendMode.srcIn,
        ),
      ),
      label: Text(l10n.readerAskAbout),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
