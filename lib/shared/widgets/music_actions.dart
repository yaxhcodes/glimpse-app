import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/music_provider.dart';
import '../../core/providers/music_provider_preference_provider.dart';
import '../../core/services/music_destination_service.dart';
import '../../l10n/l10n.dart';
import 'music_provider_icon.dart';
import 'music_provider_sheet.dart';

Future<MusicProvider?> choosePreferredMusicProvider(
  BuildContext context,
  WidgetRef ref, {
  bool onlyIfUnset = false,
}) async {
  try {
    final notifier = ref.read(musicProviderPreferenceProvider.notifier);
    await notifier.ensureLoaded();
    if (!context.mounted) return null;
    final current = ref.read(musicProviderPreferenceProvider).provider;
    if (onlyIfUnset &&
        (current != null || ModalRoute.of(context)?.isCurrent == false)) {
      return current;
    }
    final selected = await showMusicProviderSheet(context, selected: current);
    if (selected == null || !context.mounted) return null;
    await notifier.setProvider(selected);
    return selected;
  } catch (error, stackTrace) {
    developer.log(
      'Could not save music provider',
      error: error,
      stackTrace: stackTrace,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotSaveMusicProvider)),
      );
    }
    return null;
  }
}

Future<void> openMusicItem(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  String? artist,
}) async {
  try {
    await ref.read(musicProviderPreferenceProvider.notifier).ensureLoaded();
    if (!context.mounted) return;
    var provider = ref.read(musicProviderPreferenceProvider).provider;
    provider ??= await choosePreferredMusicProvider(context, ref);
    if (provider == null || !context.mounted) return;
    final uri = MusicDestinationService.searchUri(
      provider: provider,
      title: title,
      artist: artist,
      countryCode: Localizations.maybeLocaleOf(context)?.countryCode,
    );
    try {
      if (await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      )) {
        return;
      }
    } catch (error, stackTrace) {
      developer.log(
        'Music app unavailable; trying the web destination',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (error, stackTrace) {
    developer.log('Could not open music', error: error, stackTrace: stackTrace);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.couldNotOpenLink)));
  }
}

class MusicProviderMenuButton extends ConsumerStatefulWidget {
  const MusicProviderMenuButton({super.key, this.promptIfUnset = false});

  final bool promptIfUnset;

  @override
  ConsumerState<MusicProviderMenuButton> createState() =>
      _MusicProviderMenuButtonState();
}

class _MusicProviderMenuButtonState
    extends ConsumerState<MusicProviderMenuButton> {
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    if (widget.promptIfUnset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_chooseProvider(onlyIfUnset: true));
      });
    }
  }

  Future<void> _chooseProvider({bool onlyIfUnset = false}) async {
    if (!mounted || _choosing) return;
    setState(() => _choosing = true);
    await choosePreferredMusicProvider(context, ref, onlyIfUnset: onlyIfUnset);
    if (mounted) setState(() => _choosing = false);
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(musicProviderPreferenceProvider);
    final provider = preference.provider;
    final label = provider == null
        ? context.l10n.chooseWhereSongsOpen
        : '${context.l10n.musicApp}: ${provider.label}';
    return PopupMenuButton<String>(
      tooltip: context.l10n.libraryOptions(context.l10n.libraryMusic),
      enabled: preference.isLoaded && !_choosing,
      onSelected: (_) => _chooseProvider(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'provider',
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: Semantics(
              label: label,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    provider == null
                        ? const Icon(Icons.music_note_rounded, size: 32)
                        : MusicProviderIcon(provider: provider, size: 32),
                    const SizedBox(width: 12),
                    Flexible(child: Text(context.l10n.musicApp)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MusicOpenButton extends ConsumerStatefulWidget {
  const MusicOpenButton({super.key, required this.title, this.artist});

  final String title;
  final String? artist;

  @override
  ConsumerState<MusicOpenButton> createState() => _MusicOpenButtonState();
}

class _MusicOpenButtonState extends ConsumerState<MusicOpenButton> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(musicProviderPreferenceProvider).provider;
    return FilledButton.tonalIcon(
      onPressed: _opening
          ? null
          : () async {
              setState(() => _opening = true);
              await openMusicItem(
                context,
                ref,
                title: widget.title,
                artist: widget.artist,
              );
              if (mounted) setState(() => _opening = false);
            },
      icon: const Icon(Icons.open_in_new_rounded),
      label: Text(
        provider == null
            ? context.l10n.chooseWhereSongsOpen
            : context.l10n.openInSource(provider.label),
      ),
    );
  }
}
