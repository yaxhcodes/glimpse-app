import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/link_preview_service.dart';
import '../../core/services/summary_trimmer.dart';
import '../../core/services/title_resolver.dart';
import '../../core/utils/url_extractor.dart';
import '../../shared/widgets/link_card_thumbnail.dart';
import '../../shared/widgets/upgrade_gate.dart';
import 'add_url_provider.dart';

class AddUrlScreen extends ConsumerStatefulWidget {
  final String? initialUrl;

  const AddUrlScreen({super.key, this.initialUrl});

  @override
  ConsumerState<AddUrlScreen> createState() => _AddUrlScreenState();
}

class _AddUrlScreenState extends ConsumerState<AddUrlScreen> {
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _domainPreview;
  String? _clipboardPrefillUrl;
  bool _clipboardPrefilled = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_handleUrlChanged);
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      _updateDomainPreview();
    } else {
      unawaited(_prefillFromClipboard());
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_handleUrlChanged);
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleUrlChanged() {
    _updateDomainPreview();
    if (!_clipboardPrefilled) return;
    if (_urlController.text.trim() != _clipboardPrefillUrl) {
      setState(() {
        _clipboardPrefilled = false;
        _clipboardPrefillUrl = null;
      });
    }
  }

  void _updateDomainPreview() {
    final text = _urlController.text.trim();
    String? preview;
    if (text.isNotEmpty && LinkPreviewService.isValidUrl(text)) {
      try {
        var host = Uri.parse(text).host.toLowerCase();
        if (host.startsWith('www.')) host = host.substring(4);
        preview = host;
      } catch (_) {
        preview = null;
      }
    }
    if (preview != _domainPreview) {
      setState(() => _domainPreview = preview);
    }
  }

  Future<void> _prefillFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final extracted = UrlExtractor.extract(text);
      if (!mounted || extracted.urls.length != 1) return;

      final url = extracted.urls.first;
      _clipboardPrefillUrl = url;
      _clipboardPrefilled = true;
      _urlController.text = url;
      _updateDomainPreview();
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
      _clipboardPrefilled = false;
      _clipboardPrefillUrl = null;
      _urlController.text = extracted.urls.isNotEmpty
          ? extracted.urls.first
          : text;
    }
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
        .saveUrl(url, notes: notes.isNotEmpty ? notes : null);

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isSaving = state.status == AddUrlStatus.saving;
    final isEnabled =
        state.status == AddUrlStatus.idle ||
        state.status == AddUrlStatus.error ||
        state.status == AddUrlStatus.duplicate;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurfaceVariant,
            title: Text(
              'Capture something worth returning to',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Subtitle
                    Text(
                      'Add a note if you want. Glimpse will find the context after you capture it.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Grouped inputs
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // URL field
                          TextFormField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: 'https://example.com',
                              hintStyle: TextStyle(color: colorScheme.outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.content_paste_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                tooltip: 'Paste from clipboard',
                                onPressed: isEnabled
                                    ? _pasteFromClipboard
                                    : null,
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a URL';
                              }
                              return null;
                            },
                            enabled: isEnabled,
                          ),
                          const SizedBox(height: 10),

                          // Note field
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              hintText: 'Add a note (optional)',
                              hintStyle: TextStyle(color: colorScheme.outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerLow,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            maxLines: 2,
                            enabled: isEnabled,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Domain preview
                    if (_domainPreview != null && isEnabled)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            Text(
                              'From $_domainPreview',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_clipboardPrefilled) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Detected from clipboard',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Saving indicator
                    if (isSaving) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Capturing what caught your eye.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Error message
                    if (state.status == AddUrlStatus.error ||
                        state.status == AddUrlStatus.duplicate) ...[
                      const SizedBox(height: 8),
                      _DuplicateSaveNotice(
                        message: state.status == AddUrlStatus.duplicate
                            ? 'Already in Glimpse'
                            : state.errorMessage ??
                                  'Could not capture this link',
                        savedUrlId: state.savedUrlId,
                        isError: state.status == AddUrlStatus.error,
                      ),
                    ],

                    const Spacer(),

                    FilledButton(
                      onPressed: isEnabled ? _onSave : null,
                      style: FilledButton.styleFrom(
                        elevation: isEnabled ? 2 : 0,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Capture'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
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
                        'Finding the saved version...',
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
                      'Open saved item',
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
