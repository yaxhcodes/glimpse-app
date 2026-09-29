import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/summary_trimmer.dart';
import '../../core/services/title_resolver.dart';
import '../../core/utils/url_extractor.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/link_card_thumbnail.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/saved_toast.dart';
import '../../shared/widgets/upgrade_gate.dart';
import '../collections/collections_provider.dart';
import '../collections/create_collection_sheet.dart';
import '../collections/share_capture_sheet.dart';
import '../sources/source_visuals.dart';
import 'add_url_provider.dart';
import '../../l10n/l10n.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

class ManualAddArguments {
  const ManualAddArguments({this.initialCollection});

  final UserCollection? initialCollection;
}

/// Capture a link by hand. The link is shown the way the library will show
/// it as soon as it's recognised, a save that already exists is flagged
/// before Capture is tapped, and filing it into a collection is one tap.
class AddUrlScreen extends ConsumerStatefulWidget {
  final String? initialUrl;
  final UserCollection? initialCollection;

  const AddUrlScreen({super.key, this.initialUrl, this.initialCollection});

  @override
  ConsumerState<AddUrlScreen> createState() => _AddUrlScreenState();
}

class _AddUrlScreenState extends ConsumerState<AddUrlScreen> {
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  String? _clipboardPrefillUrl;
  bool _clipboardPrefilled = false;
  UserCollection? _selectedCollection;

  /// The saved copy of the link in the field, when there is one.
  SavedUrl? _existing;
  String _lookedUpUrl = '';
  Timer? _lookupDebounce;

  @override
  void initState() {
    super.initState();
    _selectedCollection = widget.initialCollection;
    _urlController.addListener(_handleUrlChanged);
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
    } else {
      unawaited(_prefillFromClipboard());
    }
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _urlController.removeListener(_handleUrlChanged);
    _urlController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _handleUrlChanged() {
    _scheduleExistingLookup();
    if (!_clipboardPrefilled) return;
    if (_urlController.text.trim() != _clipboardPrefillUrl) {
      setState(() {
        _clipboardPrefilled = false;
        _clipboardPrefillUrl = null;
      });
    }
  }

  void _scheduleExistingLookup() {
    final text = _urlController.text.trim();
    if (text == _lookedUpUrl) return;
    _lookedUpUrl = text;
    _lookupDebounce?.cancel();
    if (text.isEmpty || !LinkPreviewService.isValidUrl(text)) {
      if (_existing != null) setState(() => _existing = null);
      return;
    }
    _lookupDebounce = Timer(const Duration(milliseconds: 250), () async {
      final normalized = LinkPreviewService.normalizeUrl(text);
      SavedUrl? existing;
      try {
        existing = await ref.read(isarServiceProvider).findByRawUrl(normalized);
      } catch (_) {
        // Only a hint; saving still reports a duplicate if the lookup fails.
        return;
      }
      if (!mounted || _lookedUpUrl != text) return;
      setState(() => _existing = existing);
    });
  }

  Future<void> _prefillFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final extracted = UrlExtractor.extract(text);
      if (!mounted || extracted.urls.length != 1) return;

      final url = extracted.urls.first;
      setState(() {
        _clipboardPrefillUrl = url;
        _clipboardPrefilled = true;
        _urlController.text = url;
      });
    } catch (_) {
      // Clipboard reads can fail on some Android builds; leave the form empty.
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final text = data!.text!;
      final extracted = UrlExtractor.extract(text);
      if (extracted.hasMultiple) {
        if (mounted) {
          context.push('/batch-save', extra: extracted.urls);
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _clipboardPrefilled = false;
        _clipboardPrefillUrl = null;
        _urlController.text = extracted.urls.isNotEmpty
            ? extracted.urls.first
            : text;
      });
    }
  }

  void _clearUrl() {
    _urlController.clear();
    setState(() {
      _clipboardPrefilled = false;
      _clipboardPrefillUrl = null;
    });
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final text = _urlController.text.trim();
    final extracted = UrlExtractor.extract(text);

    // Multi-URL paste → batch preview
    if (extracted.hasMultiple) {
      if (mounted) {
        context.push('/batch-save', extra: extracted.urls);
      }
      return;
    }

    final url = text;
    final notes = _notesController.text.trim();
    final success = await ref
        .read(addUrlProvider.notifier)
        .saveUrl(
          url,
          notes: notes.isNotEmpty ? notes : null,
          collectionId: _selectedCollection?.id,
        );

    if (success && mounted) {
      final saved = ref.read(addUrlProvider);
      final savedUrlId = saved.savedUrlId;
      // Only a save that created the item can be undone; a link already in
      // Glimpse that was just filed into a collection must survive Undo.
      final undoable =
          saved.outcome == AddUrlOutcome.captured && savedUrlId != null;
      final isar = ref.read(isarServiceProvider);
      ref.read(addUrlProvider.notifier).reset();
      // App-level ScaffoldMessenger → the snackbar survives this pop.
      if (saved.aiLimitReached) {
        showAiLimitSnackBar(context, isPro: ref.read(isProUserProvider));
      } else {
        final collection = _selectedCollection;
        showSavedSnackBar(
          ScaffoldMessenger.of(context),
          context.l10n,
          label: collection == null
              ? null
              : context.l10n.savedToCollection(collection.name),
          onUndo: undoable
              ? () => unawaited(isar.deleteUrlPermanently(savedUrlId))
              : null,
        );
      }
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addUrlProvider);
    final strings = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isSaving = state.status == AddUrlStatus.saving;
    final isEnabled =
        state.status == AddUrlStatus.idle ||
        state.status == AddUrlStatus.error ||
        state.status == AddUrlStatus.duplicate;
    final saveOutcomeShown =
        state.status == AddUrlStatus.error ||
        state.status == AddUrlStatus.duplicate;
    final existing = _existing;
    final horizontalPadding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
      compactPadding: 20,
      maxContentWidth: 560,
    );

    return Form(
      key: _formKey,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(AppIcons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () {
              AppHaptics.play(AppHaptics.tick);
              context.pop();
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            4,
            horizontalPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.captureSomethingWorthReturning,
                style: AppTypography.editorial(
                  textTheme.headlineMedium,
                  color: colorScheme.onSurface,
                  height: 1.12,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                strings.captureContextAfter,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              _LinkWell(
                controller: _urlController,
                enabled: isEnabled,
                fromClipboard: _clipboardPrefilled,
                onPaste: _pasteFromClipboard,
                onClear: _clearUrl,
              ),
              // Known before Capture is tapped: this link is already saved.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: existing != null && !saveOutcomeShown
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _DuplicateSaveNotice(
                          message: strings.alreadyInGlimpse,
                          savedUrlId: existing.id,
                          isError: false,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 28),
              _SectionLabel(strings.collection),
              const SizedBox(height: 10),
              _CollectionChips(
                selected: _selectedCollection,
                enabled: isEnabled,
                onSelected: (collection) {
                  AppHaptics.play(AppHaptics.tick);
                  setState(() => _selectedCollection = collection);
                },
              ),
              const SizedBox(height: 28),
              _NoteField(
                controller: _notesController,
                focusNode: _notesFocusNode,
                enabled: isEnabled,
              ),
              if (saveOutcomeShown) ...[
                const SizedBox(height: 20),
                _DuplicateSaveNotice(
                  message: state.status == AddUrlStatus.duplicate
                      ? context.l10n.alreadyInGlimpse
                      : state.errorMessage ?? strings.couldNotCaptureLink,
                  savedUrlId: state.savedUrlId,
                  isError: state.status == AddUrlStatus.error,
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              16,
            ),
            child: SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: isEnabled
                    ? () {
                        AppHaptics.play(AppHaptics.tap);
                        _onSave();
                      }
                    : null,
                style: FilledButton.styleFrom(
                  textStyle: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: isSaving
                      ? Row(
                          key: const ValueKey('saving'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 18,
                              child: ExpressiveLoadingIndicator(size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(context.l10n.capturing),
                          ],
                        )
                      : Text(
                          context.l10n.capture,
                          key: const ValueKey('capture'),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// The link, and what it is. Once the text is a real link the well shows it
/// the way the library will: the source's logo and name over its address.
class _LinkWell extends StatefulWidget {
  const _LinkWell({
    required this.controller,
    required this.enabled,
    required this.fromClipboard,
    required this.onPaste,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool fromClipboard;
  final VoidCallback onPaste;
  final VoidCallback onClear;

  @override
  State<_LinkWell> createState() => _LinkWellState();
}

class _LinkWellState extends State<_LinkWell> {
  final _focusNode = FocusNode();

  /// A recognised link collapses to its preview; tapping it edits the text.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocus() {
    // Typing keeps the field open even once the link becomes recognisable;
    // it folds into the preview when focus leaves.
    setState(() {
      if (!_focusNode.hasFocus) _editing = false;
    });
  }

  void _edit() {
    if (!widget.enabled) return;
    AppHaptics.play(AppHaptics.tick);
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final strings = context.l10n;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final text = value.text.trim();
        final preview = _LinkPreviewData.parse(text);
        final showField = preview == null || _editing || _focusNode.hasFocus;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: preview != null
                      ? cs.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (preview != null)
                      _LinkPreviewHeader(
                        preview: preview,
                        onTap: _edit,
                        onClear: widget.enabled
                            ? () {
                                AppHaptics.play(AppHaptics.tick);
                                setState(() => _editing = false);
                                widget.onClear();
                              }
                            : null,
                      ),
                    if (showField)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          preview == null ? 12 : 0,
                          8,
                          preview == null ? 12 : 10,
                        ),
                        child: Row(
                          children: [
                            if (preview == null) ...[
                              AppIcon(
                                AppIcons.addLink,
                                size: 20,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: TextFormField(
                                controller: widget.controller,
                                focusNode: _focusNode,
                                enabled: widget.enabled,
                                keyboardType: TextInputType.url,
                                autocorrect: false,
                                minLines: 1,
                                maxLines: 3,
                                onFieldSubmitted: (_) => _focusNode.unfocus(),
                                style:
                                    (preview == null
                                            ? tt.bodyLarge
                                            : tt.bodySmall)
                                        ?.copyWith(
                                          color: preview == null
                                              ? cs.onSurface
                                              : cs.onSurfaceVariant,
                                        ),
                                decoration: InputDecoration(
                                  hintText: 'https://',
                                  hintStyle: tt.bodyLarge?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  filled: false,
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return strings.pleaseEnterUrl;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (text.isEmpty)
                              FilledButton.tonalIcon(
                                onPressed: widget.enabled
                                    ? () {
                                        AppHaptics.play(AppHaptics.tick);
                                        widget.onPaste();
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                icon: const AppIcon(AppIcons.paste, size: 18),
                                label: Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).pasteButtonLabel,
                                ),
                              )
                            else if (preview == null)
                              IconButton(
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).deleteButtonTooltip,
                                onPressed: widget.enabled
                                    ? () {
                                        AppHaptics.play(AppHaptics.tick);
                                        widget.onClear();
                                      }
                                    : null,
                                icon: Icon(
                                  AppIcons.close,
                                  size: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (preview != null && widget.fromClipboard)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    AppIcon(AppIcons.paste, size: 14, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      strings.detectedFromClipboard,
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The recognised link: logo, source name and address. Tap to edit.
class _LinkPreviewHeader extends StatelessWidget {
  const _LinkPreviewHeader({
    required this.preview,
    required this.onTap,
    required this.onClear,
  });

  final _LinkPreviewData preview;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Row(
          children: [
            SourceLogoTile(name: preview.source, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onClear,
              icon: Icon(AppIcons.close, size: 18, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the link well can say about a link without fetching it.
class _LinkPreviewData {
  const _LinkPreviewData({required this.source, required this.address});

  /// "Instagram", "YouTube", or the site's own domain.
  final String source;

  /// Host and path with the scheme and "www." dropped.
  final String address;

  static _LinkPreviewData? parse(String text) {
    if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
    if (!LinkPreviewService.isValidUrl(text)) return null;
    final normalized = LinkPreviewService.normalizeUrl(text);
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    final path = uri.path == '/' ? '' : uri.path;
    return _LinkPreviewData(
      source: CategoryResolver.displaySourceName(
        rawUrl: normalized,
        fallbackDomain: host,
      ),
      address: '$host$path',
    );
  }
}

/// One tap to file the save. The collections filed into most recently wrap
/// under the link; the rest are one search away in the full picker, so a
/// long list never turns into a sideways scroll.
class _CollectionChips extends ConsumerWidget {
  const _CollectionChips({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  /// Collections shown as chips before the rest move behind "Show all".
  static const _quickCount = 5;

  final UserCollection? selected;
  final bool enabled;
  final ValueChanged<UserCollection?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.l10n;
    final summaries = ref.watch(collectionsSummaryProvider).valueOrNull;
    final collections = summaries != null
        ? _byRecentUse(summaries)
        : ref.watch(collectionsListProvider).valueOrNull ??
              const <UserCollection>[];
    final chosen = selected;
    // The chosen collection is always on screen, even when it was picked
    // from the full list (or just created and the list hasn't reloaded).
    final top = collections.take(_quickCount).toList();
    final quick = chosen == null || top.any((c) => c.id == chosen.id)
        ? top
        : [chosen, ...top.take(_quickCount - 1)];
    final hasMore = collections.any((c) => !quick.any((q) => q.id == c.id));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CollectionChip(
          label: strings.noCollection,
          selected: chosen == null,
          onTap: enabled ? () => onSelected(null) : null,
        ),
        for (final collection in quick)
          _CollectionChip(
            label: collection.name,
            selected: chosen?.id == collection.id,
            onTap: enabled ? () => onSelected(collection) : null,
          ),
        if (hasMore)
          _CollectionChip(
            label: strings.showAllCount(collections.length),
            icon: AppIcons.search,
            selected: false,
            onTap: enabled
                ? () async {
                    AppHaptics.play(AppHaptics.tick);
                    final selection = await showOptionalCollectionPickerSheet(
                      context,
                      selectedCollectionId: chosen?.id,
                    );
                    if (selection != null) onSelected(selection.collection);
                  }
                : null,
          ),
        _CollectionChip(
          label: strings.newCollection,
          icon: AppIcons.add,
          selected: false,
          onTap: enabled
              ? () async {
                  final created = await showCreateCollectionSheet(context);
                  if (created != null) onSelected(created);
                }
              : null,
        ),
      ],
    );
  }

  /// Most recently filed into first; a collection nothing has been filed
  /// into yet counts from when it was made.
  static List<UserCollection> _byRecentUse(List<CollectionSummary> summaries) {
    DateTime activity(CollectionSummary s) {
      final added = s.lastAddedAt;
      final created = s.collection.createdAt;
      return added != null && added.isAfter(created) ? added : created;
    }

    final sorted = [...summaries]
      ..sort((a, b) => activity(b).compareTo(activity(a)));
    return [for (final s in sorted) s.collection];
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final foreground = selected ? cs.onSecondaryContainer : cs.onSurface;
    final leading = selected ? AppIcons.check : icon;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? cs.secondaryContainer : cs.surfaceContainerLow,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? Colors.transparent
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppIcon(AppIcons.note, size: 20, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: tt.bodyLarge?.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: context.l10n.addNoteOptional,
                hintStyle: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateSaveNotice extends ConsumerWidget {
  const _DuplicateSaveNotice({
    required this.message,
    required this.savedUrlId,
    required this.isError,
  });

  final String message;
  final int? savedUrlId;
  final bool isError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final id = savedUrlId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: TextStyle(
              color: isError
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (id != null) ...[
            const SizedBox(height: 12),
            FutureBuilder<SavedUrl?>(
              future: ref.read(isarServiceProvider).getUrlById(id),
              builder: (context, snapshot) {
                final url = snapshot.data;
                if (url == null) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _DuplicatePreviewShell(
                      child: Text(
                        context.l10n.findingSavedVersion,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
                return _DuplicateUrlPreview(url: url);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DuplicateUrlPreview extends StatelessWidget {
  const _DuplicateUrlPreview({required this.url});

  final SavedUrl url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title = TitleResolver.resolveDetailTitle(url);
    final detail = _previewDetail(url);

    return _DuplicatePreviewShell(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/url/${url.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinkCardThumbnail.build(
                url: url,
                isRead: url.openedAt != null,
                context: context,
                size: 54,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.openSavedItem,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _previewDetail(SavedUrl url) {
    final summary = url.summary?.trim();
    if (summary != null && summary.isNotEmpty) {
      return SummaryTrimmer.trim(summary, maxLength: 96);
    }
    final description = url.description.trim();
    if (description.isNotEmpty) {
      return SummaryTrimmer.trim(description, maxLength: 96);
    }
    return url.domain;
  }
}

class _DuplicatePreviewShell extends StatelessWidget {
  const _DuplicatePreviewShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
