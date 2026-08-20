import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import 'library_entity.dart';
import 'library_localization.dart';
import 'library_status_picker.dart';

class LibraryRadialStatusTarget extends StatefulWidget {
  const LibraryRadialStatusTarget({
    super.key,
    required this.entity,
    required this.child,
    required this.preview,
    required this.onTap,
    required this.onStatusSelected,
    required this.onStatusMenuRequested,
  });

  final LibraryEntity entity;
  final Widget child;
  final Widget preview;
  final VoidCallback onTap;
  final ValueChanged<LibraryItemStatus> onStatusSelected;
  final VoidCallback onStatusMenuRequested;

  @override
  State<LibraryRadialStatusTarget> createState() =>
      _LibraryRadialStatusTargetState();
}

class _LibraryRadialStatusTargetState extends State<LibraryRadialStatusTarget> {
  static const _cancelRadius = 34.0;
  static const _optionSize = 56.0;
  static const _optionHitRadius = 42.0;

  OverlayEntry? _overlayEntry;
  Offset? _anchor;
  Rect? _cardRect;
  bool _cardOnLeft = true;
  LibraryItemStatus? _highlightedStatus;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final listName = localizedLibraryListName(strings, widget.entity.kind);
    return Semantics(
      button: true,
      label: strings.libraryItemSemantics(
        localizedLibraryKindSingular(strings, widget.entity.kind),
        widget.entity.title,
      ),
      hint: strings.libraryItemOpenHint(listName),
      onTap: widget.onTap,
      onLongPress: widget.onStatusMenuRequested,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.onTap,
        onLongPressStart: _openOverlay,
        onLongPressMoveUpdate: (details) =>
            _updateHighlight(details.globalPosition),
        onLongPressEnd: (details) => _finish(details.globalPosition),
        onLongPressCancel: _cancel,
        child: widget.child,
      ),
    );
  }

  void _openOverlay(LongPressStartDetails details) {
    final renderObject = context.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true);
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final media = MediaQuery.of(context);
    final screenSize = media.size;
    const horizontalExtent = 76.0 + _optionSize / 2 + 8;
    const upwardExtent = 78.0 + _optionSize / 2 + 8;
    const downwardExtent = 8.0 + _optionSize / 2 + 8;
    final topLimit = media.padding.top + upwardExtent;
    final bottomLimit =
        screenSize.height - media.padding.bottom - downwardExtent;
    final position = details.globalPosition;
    final cardRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;

    _anchor = Offset(
      position.dx.clamp(horizontalExtent, screenSize.width - horizontalExtent),
      position.dy.clamp(topLimit, bottomLimit),
    );
    _cardRect = cardRect;
    _cardOnLeft = cardRect.center.dx < screenSize.width / 2;
    _highlightedStatus = null;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
    HapticFeedback.mediumImpact();
  }

  Widget _buildOverlay(BuildContext context) {
    final anchor = _anchor;
    final cardRect = _cardRect;
    if (anchor == null || cardRect == null) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    final cs = Theme.of(context).colorScheme;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          key: const ValueKey('library-radial-status-overlay'),
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                duration: duration,
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) =>
                    ColoredBox(color: cs.scrim.withValues(alpha: 0.62 * value)),
              ),
            ),
            Positioned.fromRect(
              rect: cardRect.inflate(4),
              child: TweenAnimationBuilder<double>(
                duration: duration,
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) => Transform.rotate(
                  key: ValueKey(
                    'library-radial-preview-${_cardOnLeft ? 'left' : 'right'}',
                  ),
                  angle: (_cardOnLeft ? -0.035 : 0.035) * value,
                  child: Transform.scale(
                    scale: 1 + (0.035 * value),
                    child: child,
                  ),
                ),
                child: Material(
                  color: cs.surface,
                  elevation: 12,
                  shadowColor: cs.shadow.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: widget.preview,
                  ),
                ),
              ),
            ),
            _buildGestureOrigin(context, anchor),
            for (final option in _options)
              _buildOption(context, option, anchor, duration),
            if (_highlightedStatus case final status?)
              Positioned(
                left: 24,
                right: 24,
                top: (anchor.dy + 44).clamp(
                  media.padding.top + 8,
                  media.size.height - media.padding.bottom - 54,
                ),
                child: Center(
                  child: AnimatedContainer(
                    key: const ValueKey('library-radial-status-label'),
                    duration: duration,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.inverseSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      localizedLibraryStatus(
                        context.l10n,
                        status,
                        widget.entity.kind,
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    _RadialStatusOption option,
    Offset anchor,
    Duration duration,
  ) {
    final selected = option.status == _highlightedStatus;
    final center = _optionCenter(option, anchor);
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      key: ValueKey('library-radial-${option.status.name}'),
      left: center.dx - _optionSize / 2,
      top: center.dy - _optionSize / 2,
      width: _optionSize,
      height: _optionSize,
      child: AnimatedScale(
        duration: duration,
        curve: Curves.easeOutBack,
        scale: selected ? 1.16 : 1,
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: selected ? 0.35 : 0.22),
                blurRadius: selected ? 16 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            libraryStatusIcon(option.status, widget.entity.kind),
            color: selected ? cs.onPrimary : cs.onSurface,
            size: 25,
          ),
        ),
      ),
    );
  }

  Widget _buildGestureOrigin(BuildContext context, Offset anchor) {
    final cs = Theme.of(context).colorScheme;
    const size = 54.0;
    return Positioned(
      key: const ValueKey('library-radial-origin'),
      left: anchor.dx - size / 2,
      top: anchor.dy - size / 2,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.58),
            width: 2,
          ),
        ),
      ),
    );
  }

  Offset _optionCenter(_RadialStatusOption option, Offset anchor) {
    final offset = option.offset;
    return anchor + Offset(_cardOnLeft ? -offset.dx : offset.dx, offset.dy);
  }

  void _updateHighlight(Offset globalPosition) {
    final anchor = _anchor;
    if (anchor == null) return;
    final delta = globalPosition - anchor;
    LibraryItemStatus? next;
    if (delta.distance >= _cancelRadius) {
      final nearest = _options.reduce((a, b) {
        final aDistance =
            (_optionCenter(a, anchor) - globalPosition).distanceSquared;
        final bDistance =
            (_optionCenter(b, anchor) - globalPosition).distanceSquared;
        return aDistance <= bDistance ? a : b;
      });
      if ((_optionCenter(nearest, anchor) - globalPosition).distance <=
          _optionHitRadius) {
        next = nearest.status;
      }
    }
    if (next == _highlightedStatus) return;
    _highlightedStatus = next;
    _overlayEntry?.markNeedsBuild();
    if (next != null) HapticFeedback.selectionClick();
  }

  void _finish(Offset globalPosition) {
    _updateHighlight(globalPosition);
    final selected = _highlightedStatus;
    _removeOverlay();
    if (selected == null || selected == widget.entity.status) return;
    HapticFeedback.lightImpact();
    widget.onStatusSelected(selected);
  }

  void _cancel() => _removeOverlay();

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _anchor = null;
    _cardRect = null;
    _highlightedStatus = null;
  }
}

const _options = [
  _RadialStatusOption(LibraryItemStatus.planning, Offset(-54, -52)),
  _RadialStatusOption(LibraryItemStatus.active, Offset(0, -78)),
  _RadialStatusOption(LibraryItemStatus.completed, Offset(54, -52)),
  _RadialStatusOption(LibraryItemStatus.dropped, Offset(-76, 8)),
];

class _RadialStatusOption {
  const _RadialStatusOption(this.status, this.offset);

  final LibraryItemStatus status;
  final Offset offset;
}
