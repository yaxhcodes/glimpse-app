import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/category_resolver.dart';
import 'ask_provider.dart';

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key});

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    _controller.clear();
    ref.read(askProvider.notifier).ask(question);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final askState = ref.watch(askProvider);
    final theme = Theme.of(context);

    ref.listen(askProvider, (_, next) {
      if (!next.isLoading) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Glimpse'),
        actions: [
          if (askState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear conversation',
              onPressed: () => ref.read(askProvider.notifier).clearHistory(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: askState.messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: askState.messages.length +
                        (askState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == askState.messages.length) {
                        return const _TypingIndicator();
                      }
                      final msg = askState.messages[index];
                      return _ChatBubble(message: msg);
                    },
                  ),
          ),
          _InputBar(
            controller: _controller,
            isLoading: askState.isLoading,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good evening';
  }

  Widget _buildEmptyState(ThemeData theme) {
    final suggestions = [
      'What did I save recently?',
      'Summarise my links about technology',
      'What topics do I read about most?',
      'Find something about productivity',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          ClipOval(
            child: Image.asset(
              'assets/unown_bookmark_transparent.png',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${_greeting()}!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask anything about your saved links',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  _controller.text = s;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: s.length),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Icon(
                        Icons.north_west,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isUser ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isUser ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
              if (!isUser) ...[
                const SizedBox(height: 14),
                const _AssistantBrandHeader(),
              ],
              if (!isUser && message.sections.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (var index = 0; index < message.sections.length; index++) ...[
                  _AnswerSectionCard(
                    order: index + 1,
                    section: message.sections[index],
                  ),
                  if (index != message.sections.length - 1)
                    const SizedBox(height: 12),
                ],
              ] else if (!isUser && message.sources.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (var index = 0; index < message.sources.length; index++) ...[
                  _SourceCard(
                    source: message.sources[index],
                    order: index + 1,
                  ),
                  if (index != message.sources.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantBrandHeader extends StatelessWidget {
  const _AssistantBrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/unown_bookmark_transparent.png',
            width: 26,
            height: 26,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Glimpse',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AnswerSectionCard extends StatelessWidget {
  const _AnswerSectionCard({
    required this.order,
    required this.section,
  });

  final int order;
  final ChatMessageSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$order',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.heading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            section.summary,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _SourceCard(source: section.source, order: order),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.order});

  final SavedUrl source;
  final int order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: source.rawUrl,
      fallbackDomain: source.domain,
    );
    final metaLabel = source.category == displaySourceName
        ? '${source.categoryEmoji} ${source.category}'
        : '${source.categoryEmoji} ${source.category} • $displaySourceName';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Source $order',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            source.title.isNotEmpty ? source.title : source.domain,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metaLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _openUrl(source.rawUrl),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/url/${source.id}'),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 40,
          height: 20,
          child: _ThreeDotsAnimation(),
        ),
      ),
    );
  }
}

class _ThreeDotsAnimation extends StatefulWidget {
  const _ThreeDotsAnimation();

  @override
  State<_ThreeDotsAnimation> createState() => _ThreeDotsAnimationState();
}

class _ThreeDotsAnimationState extends State<_ThreeDotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (_, snap) {
        final color = Theme.of(context).colorScheme.onSurfaceVariant;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final progress = (_animController.value - delay).clamp(0.0, 1.0);
            final opacity = (progress < 0.5 ? progress * 2 : (1 - progress) * 2)
                .clamp(0.3, 1.0);
            return Opacity(
              opacity: opacity,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSubmit(),
                maxLines: null,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Chat with Glimpse...',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
