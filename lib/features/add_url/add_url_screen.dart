import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/link_preview_service.dart';
import '../../core/services/usage_service.dart';
import '../../shared/widgets/usage_badge.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      _updateDomainPreview();
    }
    _urlController.addListener(_updateDomainPreview);
  }

  @override
  void dispose() {
    _urlController.removeListener(_updateDomainPreview);
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final url = _urlController.text.trim();
    final notes = _notesController.text.trim();
    final success = await ref
        .read(addUrlProvider.notifier)
        .saveUrl(url, notes: notes.isNotEmpty ? notes : null);

    if (success && mounted) {
      ref.read(addUrlProvider.notifier).reset();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addUrlProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isEnabled = state.status == AddUrlStatus.idle ||
        state.status == AddUrlStatus.error;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Save something worth keeping'),
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
                      'Paste a link and add a note if you want.',
                      style: textTheme.bodyMedium?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Grouped inputs
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // URL field
                          TextFormField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: 'https://example.com',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.paste),
                                tooltip: 'Paste from clipboard',
                                onPressed: _pasteFromClipboard,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
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
                          const SizedBox(height: 16),

                          // Note field
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              hintText: 'Add a note (optional)',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            maxLines: 2,
                            enabled: isEnabled,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.85),
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
                        child: Text(
                          'From $_domainPreview',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Status indicator
                    if (state.status != AddUrlStatus.idle &&
                        state.status != AddUrlStatus.error) ...[
                      _StatusStep(
                        label: 'Fetching page metadata...',
                        isActive:
                            state.status == AddUrlStatus.fetchingMetadata,
                        isDone: state.status.index >
                            AddUrlStatus.fetchingMetadata.index,
                      ),
                      _StatusStep(
                        label: 'AI categorizing & summarizing...',
                        isActive:
                            state.status == AddUrlStatus.categorizing,
                        isDone: state.status.index >
                            AddUrlStatus.categorizing.index,
                      ),
                      _StatusStep(
                        label: 'Generating embedding...',
                        isActive:
                            state.status == AddUrlStatus.generatingEmbedding,
                        isDone: state.status.index >
                            AddUrlStatus.generatingEmbedding.index,
                      ),
                      _StatusStep(
                        label: 'Saving to library...',
                        isActive: state.status == AddUrlStatus.saving,
                        isDone: state.status == AddUrlStatus.done,
                      ),
                    ],

                    // Duplicate similarity warning
                    if (state.status == AddUrlStatus.saving &&
                        state.similarUrlCount != null &&
                        state.similarUrlCount! > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color:
                                    theme.colorScheme.onTertiaryContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You already have ${state.similarUrlCount} similar link${state.similarUrlCount! > 1 ? 's' : ''} saved.',
                                style: TextStyle(
                                    color: theme.colorScheme
                                        .onTertiaryContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // AI-limit fallback warning
                    if (state.usedAiFallback) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "You've reached your monthly AI save limit. This link was saved with basic categorization. Upgrade to Pro for unlimited AI saves.",
                                style: TextStyle(
                                  color:
                                      theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Error message
                    if (state.status == AddUrlStatus.error &&
                        state.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Usage indicator
                    const UsageInlineIndicator(feature: UsageFeature.aiSave),
                    const SizedBox(height: 8),

                    FilledButton(
                      onPressed: isEnabled ? _onSave : null,
                      style: FilledButton.styleFrom(
                        elevation: isEnabled ? 2 : 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save to Glimpse'),
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

class _StatusStep extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDone;

  const _StatusStep({
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (isDone)
            Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20)
          else if (isActive)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.circle_outlined,
                color: theme.colorScheme.outlineVariant, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDone || isActive
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
