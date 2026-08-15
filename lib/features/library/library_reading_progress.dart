import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'library_entity.dart';

class LibraryReadingProgressCard extends StatelessWidget {
  const LibraryReadingProgressCard({
    super.key,
    required this.entity,
    required this.onPageChanged,
  });

  final LibraryEntity entity;
  final Future<void> Function(int page) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentPage = entity.currentPage;
    final pageCount = entity.pageCount;
    return Material(
      key: const ValueKey('library-reading-progress-card'),
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.bookmark_rounded,
                      size: 22,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your bookmark',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentPage == null
                            ? _pageCountLabel(pageCount)
                            : _currentPageLabel(currentPage, pageCount),
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (entity.readingProgress case final progress?) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _choosePage(context),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(
                  currentPage == null ? 'Set current page' : 'Update page',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choosePage(BuildContext context) async {
    final page = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _ReadingPageSheet(entity: entity),
    );
    if (page == null || page == entity.currentPage) return;
    await onPageChanged(page);
  }

  static String _pageCountLabel(int? pageCount) => pageCount == null
      ? 'Save the page you’re on'
      : 'Save your place · about $pageCount pages';

  static String _currentPageLabel(int currentPage, int? pageCount) {
    if (pageCount == null) return 'Page $currentPage';
    return 'Page $currentPage · about $pageCount pages';
  }
}

class _ReadingPageSheet extends StatefulWidget {
  const _ReadingPageSheet({required this.entity});

  final LibraryEntity entity;

  @override
  State<_ReadingPageSheet> createState() => _ReadingPageSheetState();
}

class _ReadingPageSheetState extends State<_ReadingPageSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.entity.currentPage?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update your bookmark',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            widget.entity.pageCount == null
                ? widget.entity.title
                : '${widget.entity.title} · about ${widget.entity.pageCount} pages',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('library-current-page-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 5,
            decoration: InputDecoration(
              labelText: 'Current page',
              hintText: 'Enter a page number',
              errorText: _errorText,
              counterText: '',
              prefixIcon: const Icon(Icons.bookmark_outline_rounded),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save bookmark'),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final page = int.tryParse(_controller.text.trim());
    if (page == null || page < 1) {
      setState(() => _errorText = 'Enter a page number greater than zero');
      return;
    }
    Navigator.pop(context, page);
  }
}
