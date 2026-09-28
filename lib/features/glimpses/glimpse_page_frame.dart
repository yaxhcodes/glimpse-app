import 'package:flutter/material.dart';

import '../../shared/theme/app_typography.dart';

/// The frame Rediscover and Your Glimpses share: a serif page title with a
/// one-line subtitle that hands its name to the app bar once scrolled away,
/// pull to refresh, and a single scrolling column of sections.
class GlimpsePageFrame extends StatefulWidget {
  const GlimpsePageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.children,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  State<GlimpsePageFrame> createState() => _GlimpsePageFrameState();
}

class _GlimpsePageFrameState extends State<GlimpsePageFrame> {
  final _titleInBar = ValueNotifier(false);

  @override
  void dispose() {
    _titleInBar.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _titleInBar.value = notification.metrics.pixels > 56;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? cs.surfaceContainer
              : theme.scaffoldBackgroundColor,
        ),
        surfaceTintColor: Colors.transparent,
        // Mounted only once the page title has scrolled away, so the name is
        // on screen once, not twice.
        title: ValueListenableBuilder<bool>(
          valueListenable: _titleInBar,
          builder: (context, inBar, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: inBar
                ? Text(
                    widget.title,
                    key: const ValueKey('bar-title'),
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-title')),
          ),
        ),
        actions: [...widget.actions, const SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.editorial(
                        tt.headlineLarge,
                        color: cs.onSurface,
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              ...widget.children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A section heading inside a Glimpses page.
class GlimpseSectionTitle extends StatelessWidget {
  const GlimpseSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rows on one rounded surface divided by hairlines, the grouped list the
/// app uses for settings and sources.
class GlimpseGroupedList extends StatelessWidget {
  const GlimpseGroupedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}
