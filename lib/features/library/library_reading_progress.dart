import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
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
                        context.l10n.yourBookmark,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentPage == null
                            ? _pageCountLabel(context, pageCount)
                            : _currentPageLabel(
                                context,
                                currentPage,
                                pageCount,
                              ),
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
                  currentPage == null
                      ? context.l10n.setCurrentPage
                      : context.l10n.updatePage,
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

  static String _pageCountLabel(BuildContext context, int? pageCount) =>
      pageCount == null
      ? context.l10n.savePageYouAreOn
      : context.l10n.savePlaceAboutPages(pageCount);

  static String _currentPageLabel(
    BuildContext context,
    int currentPage,
    int? pageCount,
  ) {
    if (pageCount == null) return context.l10n.pageNumber(currentPage);
    return context.l10n.pageAboutPages(pageCount, currentPage);
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
            context.l10n.updateYourBookmark,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            widget.entity.pageCount == null
                ? widget.entity.title
                : '${widget.entity.title} · ${context.l10n.aboutPages(widget.entity.pageCount!)}',
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
              labelText: context.l10n.currentPage,
              hintText: context.l10n.enterPageNumber,
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
              child: Text(context.l10n.saveBookmark),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final page = int.tryParse(_controller.text.trim());
    if (page == null || page < 1) {
      setState(() => _errorText = context.l10n.pageGreaterThanZero);
      return;
    }
    Navigator.pop(context, page);
  }
}
