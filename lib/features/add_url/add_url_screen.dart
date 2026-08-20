import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/summary_trimmer.dart';
import '../../core/services/title_resolver.dart';
import '../../core/utils/url_extractor.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/link_card_thumbnail.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/upgrade_gate.dart';
import '../collections/share_capture_sheet.dart';
import 'add_url_provider.dart';
import '../../l10n/l10n.dart';

class ManualAddArguments {
  const ManualAddArguments({this.initialCollection});

  final UserCollection? initialCollection;
}

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

  @override
  void initState() {
    super.initState();
    _selectedCollection = widget.initialCollection;
    _urlController.addListener(_handleUrlChanged);
    _notesFocusNode.addListener(_handleNotesFocusChanged);
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
    } else {
      unawaited(_prefillFromClipboard());
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_handleUrlChanged);
    _notesFocusNode.removeListener(_handleNotesFocusChanged);
    _urlController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _handleNotesFocusChanged() {
    setState(() {});
  }

  void _handleUrlChanged() {
    if (!_clipboardPrefilled) return;
    if (_urlController.text.trim() != _clipboardPrefillUrl) {
      setState(() {
        _clipboardPrefilled = false;
        _clipboardPrefillUrl = null;
      });
    }
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

  Future<void> _chooseCollection() async {
    final selection = await showOptionalCollectionPickerSheet(
      context,
      selectedCollectionId: _selectedCollection?.id,
    );
    if (!mounted || selection == null) return;
    setState(() => _selectedCollection = selection.collection);
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
      final aiLimitReached = ref.read(addUrlProvider).aiLimitReached;
      ref.read(addUrlProvider.notifier).reset();
      // App-level ScaffoldMessenger → the snackbar survives this pop.
      if (aiLimitReached) showAiLimitSnackBar(context);
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
    final horizontalPadding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
      compactPadding: 20,
      maxContentWidth: 560,
    );

    return Form(
      key: _formKey,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.captureSomethingWorthReturning,
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.captureContextAfter,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  label: _FieldLabelPill(strings.link),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: 'https://example.com',
                  helperText: _clipboardPrefilled
                      ? strings.detectedFromClipboard
                      : null,
                  helperStyle: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_go_rounded),
                    tooltip: context.l10n.pasteFromClipboard,
                    onPressed: isEnabled ? _pasteFromClipboard : null,
                  ),
                ),
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return strings.pleaseEnterUrl;
                  }
                  return null;
                },
                enabled: isEnabled,
              ),
              const SizedBox(height: 16),
              _CollectionSelector(
                collection: _selectedCollection,
                enabled: isEnabled,
                onTap: _chooseCollection,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                focusNode: _notesFocusNode,
                decoration: InputDecoration(
                  label: _notesFocusNode.hasFocus
                      ? _FieldLabelPill(strings.noteOptional)
                      : null,
                  floatingLabelBehavior: _notesFocusNode.hasFocus
                      ? FloatingLabelBehavior.always
                      : FloatingLabelBehavior.never,
                  hintText: _notesFocusNode.hasFocus
                      ? null
                      : strings.addNoteOptional,
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 5,
                enabled: isEnabled,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              if (state.status == AddUrlStatus.error ||
                  state.status == AddUrlStatus.duplicate) ...[
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
            child: FilledButton(
              onPressed: isEnabled ? _onSave : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: isSaving
                    ? Row(
                        key: ValueKey('saving'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: ExpressiveLoadingIndicator(size: 18),
                          ),
                          SizedBox(width: 10),
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
    );
  }
}

class _FieldLabelPill extends StatelessWidget {
  const _FieldLabelPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primary,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CollectionSelector extends StatelessWidget {
  const _CollectionSelector({
    required this.collection,
    required this.enabled,
    required this.onTap,
  });

  final UserCollection? collection;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(20);
    final strings = context.l10n;
    final selectedName = collection?.name ?? strings.noCollection;

    return Semantics(
      button: true,
      enabled: enabled,
      label: strings.collectionSelection(selectedName),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: enabled ? onTap : null,
          child: InputDecorator(
            isEmpty: false,
            decoration: InputDecoration(
              label: _FieldLabelPill(strings.collection),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              enabled: enabled,
              suffixIcon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
            child: Text(
              selectedName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
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
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(10),
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
                borderRadius: 9,
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
                        fontWeight: FontWeight.w700,
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
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
