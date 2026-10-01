import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/service_providers.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/vault/vault_crypto.dart';
import '../../core/services/vault/vault_repository.dart';
import '../../features/add_url/add_url_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/source_icon_resolver.dart';
import '../../shared/widgets/source_logo.dart';
import '../glimpses/glimpse_page_frame.dart';
import 'vault_provider.dart';

/// The Vault: private saves behind the phone's own lock.
///
/// The screen stays out of screenshots and the recent-apps preview while
/// it's up, asks for the fingerprint / face / screen lock as it opens, and
/// locks again the moment the app goes to the background or the screen
/// closes.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen>
    with WidgetsBindingObserver {
  late final VaultCrypto _crypto = ref.read(vaultCryptoProvider);
  bool _askedOnOpen = false;
  final _search = TextEditingController();

  /// Search shows once a list is long enough to need it.
  static const _searchFrom = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_crypto.setSecureScreen(true));
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_crypto.setSecureScreen(false));
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(vaultControllerProvider.notifier);
    final phase = ref.read(vaultControllerProvider).phase;
    // The unlock prompt itself can pause the app; only an open vault locks.
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        phase == VaultPhase.open) {
      unawaited(controller.lock());
    }
    if (state == AppLifecycleState.resumed) {
      _restoreSystemBars();
      if (phase == VaultPhase.noScreenLock) {
        unawaited(controller.checkDevice());
      }
    }
  }

  Future<void> _prepare() async {
    final controller = ref.read(vaultControllerProvider.notifier);
    await controller.checkDevice();
    if (!mounted || _askedOnOpen) return;
    _askedOnOpen = true;
    if (ref.read(vaultControllerProvider).phase != VaultPhase.locked) return;
    // Nothing to open: the empty vault (or the Pro offer), no prompt.
    final count = await ref.read(vaultRepositoryProvider).count();
    if (!mounted || count == 0) return;
    await _unlock();
  }

  Future<void> _unlock() async {
    final strings = context.l10n;
    await ref
        .read(vaultControllerProvider.notifier)
        .unlock(
          title: strings.vaultUnlockPromptTitle,
          subtitle: strings.vaultUnlockPromptSubtitle,
        );
    _restoreSystemBars();
  }

  /// The PIN / password screen is Android's own and restyles the status
  /// and navigation bars; Flutter doesn't resend a style it thinks is
  /// already applied, so ask it to put ours back.
  void _restoreSystemBars() {
    unawaited(SystemChrome.restoreSystemUIOverlays());
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<bool> _confirmDestructive({
    required String title,
    required String body,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final cs = Theme.of(dialogContext).colorScheme;
            return AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(dialogContext.l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(action),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _reset() async {
    final strings = context.l10n;
    final confirmed = await _confirmDestructive(
      title: strings.vaultResetQuestion,
      body: strings.vaultResetBody,
      action: strings.vaultReset,
    );
    if (!confirmed || !mounted) return;
    final controller = ref.read(vaultControllerProvider.notifier);
    // Wiping is as final as it gets: the phone's own lock has to agree.
    final done = await controller.reset(
      title: strings.vaultReset,
      subtitle: strings.vaultResetPromptSubtitle,
    );
    _restoreSystemBars();
    if (!done || !mounted) return;
    AppHaptics.play(AppHaptics.confirm);
    await controller.checkDevice();
    _snack(strings.vaultResetDone);
  }

  Future<void> _open(VaultEntry entry) async {
    final uri = Uri.tryParse(entry.url);
    final opened =
        uri != null &&
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        ).catchError((_) => false);
    if (opened || !mounted) return;
    _snack(context.l10n.couldNotOpenLink);
  }

  Future<void> _copy(VaultEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.url));
    if (mounted) _snack(context.l10n.linkCopied);
  }

  Future<void> _rename(VaultEntry entry) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _VaultTextDialog(
        title: context.l10n.vaultRename,
        initial: entry.title ?? '',
        // Left empty, it goes back to showing the link.
        hint: entry.url.replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
        maxLength: 120,
      ),
    );
    if (name == null || !mounted) return;
    final trimmed = name.trim();
    await ref
        .read(vaultControllerProvider.notifier)
        .rename(entry, trimmed.isEmpty ? null : trimmed);
  }

  Future<void> _editNote(VaultEntry entry) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _VaultTextDialog(
        title: context.l10n.vaultEditNote,
        initial: entry.note ?? '',
        multiline: true,
      ),
    );
    if (note == null || !mounted) return;
    final trimmed = note.trim();
    await ref
        .read(vaultControllerProvider.notifier)
        .updateNote(entry, trimmed.isEmpty ? null : trimmed);
  }

  /// Back into the saves, where it's enriched like any new save. The vault
  /// copy goes only once the save has landed.
  Future<void> _moveOut(VaultEntry entry) async {
    final strings = context.l10n;
    final addUrl = ref.read(addUrlProvider.notifier);
    try {
      await addUrl.saveUrl(entry.url, notes: entry.note);
      final state = ref.read(addUrlProvider);
      final savedId = state.savedUrlId;
      addUrl.reset();
      if (savedId == null) {
        _snack(strings.vaultCouldNotMove);
        return;
      }
      final note = entry.note?.trim() ?? '';
      if (state.outcome == AddUrlOutcome.alreadySaved && note.isNotEmpty) {
        await ref
            .read(savedNotesServiceProvider)
            .appendPersonalNote(savedId, note);
      }
      await ref.read(vaultControllerProvider.notifier).delete(entry);
      AppHaptics.play(AppHaptics.success);
      _snack(strings.vaultMovedOut);
    } catch (_) {
      addUrl.reset();
      _snack(strings.vaultCouldNotMove);
    }
  }

  Future<void> _delete(VaultEntry entry) async {
    final strings = context.l10n;
    final confirmed = await _confirmDestructive(
      title: strings.vaultDeleteQuestion,
      body: strings.vaultDeleteBody,
      action: strings.delete,
    );
    if (!confirmed || !mounted) return;
    await ref.read(vaultControllerProvider.notifier).delete(entry);
    AppHaptics.play(AppHaptics.tick);
    _snack(strings.vaultDeleted);
  }

  void _showHowItWorks() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.l10n.vaultHowItWorks,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const _VaultPromises(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(vaultControllerProvider);
    final isPro = ref.watch(isProUserProvider);
    final count = ref.watch(vaultCountProvider).valueOrNull;

    // Locking forgets the search with everything else.
    ref.listen(vaultControllerProvider, (previous, next) {
      if (previous?.isOpen == true && !next.isOpen) _search.clear();
    });

    // Something was shared in while the vault was open: show it.
    ref.listen(vaultCountProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final now = next.valueOrNull;
      if (before != null && now != null && now > before && state.isOpen) {
        unawaited(ref.read(vaultControllerProvider.notifier).refresh());
      }
    });

    final emptyAndLocked = count == 0 && state.phase == VaultPhase.locked;
    final openButEmpty =
        state.isOpen && state.entries.isEmpty && state.unreadable == 0;
    final unlocking = state.phase == VaultPhase.unlocking;

    final (String stage, Widget content) = switch (state.phase) {
      VaultPhase.noScreenLock => (
        'no-lock',
        _VaultStage(
          icon: AppIcons.lock,
          title: strings.vaultNoScreenLockTitle,
          body: strings.vaultNoScreenLockBody,
        ),
      ),
      VaultPhase.invalidated => (
        'invalidated',
        _VaultStage(
          icon: AppIcons.error,
          title: strings.vaultInvalidatedTitle,
          body: strings.vaultInvalidatedBody,
          action: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: _reset,
            child: Text(strings.vaultReset),
          ),
        ),
      ),
      _ when emptyAndLocked && !isPro => (
        'offer',
        _VaultStage(
          icon: AppIcons.vault,
          title: strings.vaultProTitle,
          body: strings.vaultProBody,
          details: const _VaultPromises(),
          action: FilledButton(
            onPressed: () => context.push('/settings/subscription'),
            child: Text(strings.vaultSeePro),
          ),
        ),
      ),
      _ when emptyAndLocked || openButEmpty => (
        'empty',
        _VaultStage(
          icon: AppIcons.vault,
          title: strings.vaultEmptyTitle,
          body: strings.vaultEmptyBody,
          footnote: strings.vaultFootnote,
        ),
      ),
      VaultPhase.locked || VaultPhase.unlocking => (
        'locked',
        _VaultStage(
          icon: AppIcons.lock,
          turning: unlocking,
          title: strings.vaultLockedTitle,
          body: strings.vaultLockedBody,
          caption: count == null || count == 0
              ? null
              : strings.vaultItemCount(count),
          details: switch (state.lastUnlock) {
            VaultUnlockStatus.lockout => _UnlockProblem(
              strings.vaultUnlockLockout,
            ),
            VaultUnlockStatus.failed => _UnlockProblem(
              strings.vaultUnlockFailed,
            ),
            _ => null,
          },
          action: FilledButton.icon(
            onPressed: unlocking
                ? null
                : () {
                    AppHaptics.play(AppHaptics.tick);
                    unawaited(_unlock());
                  },
            icon: unlocking
                ? const ExpressiveLoadingIndicator(size: 18)
                : const Icon(AppIcons.fingerprint),
            label: Text(strings.vaultUnlock),
          ),
          footnote: strings.vaultFootnote,
        ),
      ),
      VaultPhase.open => ('open', _openList(context, state)),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? cs.surfaceContainer
              : Theme.of(context).scaffoldBackgroundColor,
        ),
        surfaceTintColor: Colors.transparent,
        actions: [
          if (state.isOpen)
            IconButton(
              tooltip: strings.vaultLock,
              onPressed: () {
                AppHaptics.play(AppHaptics.tick);
                unawaited(ref.read(vaultControllerProvider.notifier).lock());
              },
              icon: const Icon(AppIcons.lock),
            ),
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            tooltip: strings.more,
            onSelected: (value) {
              AppHaptics.play(AppHaptics.tap);
              if (value == 'how') _showHowItWorks();
              if (value == 'reset') unawaited(_reset());
            },
            itemBuilder: (context) => [
              appMenuItem(
                value: 'how',
                icon: AppIcons.about,
                label: strings.vaultHowItWorks,
              ),
              if ((count ?? 0) > 0 || state.phase == VaultPhase.invalidated)
                appMenuItem(
                  value: 'reset',
                  icon: AppIcons.deleteForever,
                  label: strings.vaultReset,
                  destructive: true,
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Locked to open (and back) dissolves rather than cuts.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.97, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(stage), child: content),
      ),
    );
  }

  Widget _openList(BuildContext context, VaultState state) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final gutter = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthFormat = DateFormat.yMMMM(locale);
    final dayFormat = DateFormat.MMMd(locale);
    final total = state.entries.length + state.unreadable;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter + 4, 4, gutter + 4, 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.vault,
                  style: tt.headlineMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${strings.vaultItemCount(total)}  ·  '
                  '${strings.vaultLocksOnLeave}',
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.entries.length >= _searchFrom)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 4),
            sliver: SliverToBoxAdapter(
              child: _VaultSearchField(controller: _search),
            ),
          ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _search,
          builder: (context, value, _) {
            final query = value.text.trim().toLowerCase();
            final shown = query.isEmpty
                ? state.entries
                : state.entries.where((e) => e.matches(query)).toList();
            if (shown.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 48, gutter, 32),
                  child: Text(
                    strings.vaultNoMatches,
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              );
            }
            // Months, newest first, the way the vault was filled.
            final months = <(String, List<VaultEntry>)>[];
            for (final entry in shown) {
              final month = monthFormat.format(entry.createdAt);
              if (months.isEmpty || months.last.$1 != month) {
                months.add((month, [entry]));
              } else {
                months.last.$2.add(entry);
              }
            }
            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverList.list(
                children: [
                  for (final (month, entries) in months) ...[
                    GlimpseSectionTitle(month),
                    GlimpseGroupedList(
                      children: [
                        for (final entry in entries)
                          _VaultRow(
                            entry: entry,
                            date: dayFormat.format(entry.createdAt),
                            onOpen: () => unawaited(_open(entry)),
                            onAction: (action) => _onRowAction(action, entry),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (state.unreadable > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      strings.vaultUnreadable(state.unreadable),
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                  ),
                _VaultFootnote(strings.vaultFootnote),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onRowAction(String action, VaultEntry entry) {
    AppHaptics.play(AppHaptics.tap);
    switch (action) {
      case 'copy':
        unawaited(_copy(entry));
      case 'rename':
        unawaited(_rename(entry));
      case 'note':
        unawaited(_editNote(entry));
      case 'out':
        unawaited(_moveOut(entry));
      case 'delete':
        unawaited(_delete(entry));
    }
  }
}

/// Every state that isn't the list: the dial, a title and a line or two,
/// what went wrong if anything did, then one thing to do, seated at the
/// bottom where a thumb finds it.
class _VaultStage extends StatelessWidget {
  const _VaultStage({
    required this.icon,
    required this.title,
    required this.body,
    this.turning = false,
    this.caption,
    this.details,
    this.action,
    this.footnote,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool turning;
  final String? caption;
  final Widget? details;
  final Widget? action;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final gutter = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _VaultDial(icon: icon, turning: turning),
                          const SizedBox(height: 28),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: tt.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                          if (caption != null) ...[
                            const SizedBox(height: 18),
                            _CountPill(caption!),
                          ],
                          if (details != null) ...[
                            const SizedBox(height: 24),
                            details!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (action != null)
                  SizedBox(width: double.infinity, height: 56, child: action),
                if (footnote != null) ...[
                  const SizedBox(height: 14),
                  _VaultFootnote(footnote!),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The vault's mark: a safe's dial, drawn as fine rings and tick marks in
/// the theme's own colour, around the glyph for where things stand. The
/// dial turns while the phone checks who's there.
class _VaultDial extends StatefulWidget {
  const _VaultDial({required this.icon, this.turning = false});

  final IconData icon;
  final bool turning;

  @override
  State<_VaultDial> createState() => _VaultDialState();
}

class _VaultDialState extends State<_VaultDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_VaultDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turning != widget.turning) _sync();
  }

  void _sync() {
    if (widget.turning) {
      _turn.repeat();
    } else {
      _turn.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: 208,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _turn,
                builder: (context, _) => CustomPaint(
                  painter: _DialPainter(
                    color: cs.primary,
                    turn: still ? 0 : _turn.value,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: AppIcon(
                widget.icon,
                key: ValueKey(widget.icon),
                size: 40,
                filled: true,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.color, required this.turn});

  final Color color;

  /// 0..1, one full revolution of the outer ticks.
  final double turn;

  static const _ticks = 72;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Three hairline rings, fading outward.
    for (final (fraction, alpha) in [(0.6, 0.16), (0.75, 0.11), (0.98, 0.08)]) {
      ring.color = color.withValues(alpha: alpha);
      canvas.drawCircle(center, radius * fraction, ring);
    }
    // The dial's graduations between the outer rings; every sixth is long.
    final tick = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(turn * 2 * math.pi);
    for (var i = 0; i < _ticks; i++) {
      final major = i % 6 == 0;
      tick.color = color.withValues(alpha: major ? 0.32 : 0.16);
      final outer = radius * 0.92;
      final inner = outer - (major ? 9 : 4);
      final angle = i * 2 * math.pi / _ticks;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(direction * inner, direction * outer, tick);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.turn != turn || old.color != color;
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: cs.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _UnlockProblem extends StatelessWidget {
  const _UnlockProblem(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}

/// "Only on this phone · never uploaded", under the vault's main action.
class _VaultFootnote extends StatelessWidget {
  const _VaultFootnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(AppIcons.lock, size: 13, filled: true, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// A one-field dialog that owns its controller, so the field can keep
/// building through the dialog's closing animation.
class _VaultTextDialog extends StatefulWidget {
  const _VaultTextDialog({
    required this.title,
    required this.initial,
    this.hint,
    this.maxLength,
    this.multiline = false,
  });

  final String title;
  final String initial;
  final String? hint;
  final int? maxLength;
  final bool multiline;

  @override
  State<_VaultTextDialog> createState() => _VaultTextDialogState();
}

class _VaultTextDialogState extends State<_VaultTextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        minLines: widget.multiline ? 2 : 1,
        maxLines: widget.multiline ? 5 : 1,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: widget.multiline
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: widget.multiline ? null : (_) => _submit(),
        decoration: InputDecoration(hintText: widget.hint, counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
      ],
    );
  }
}

/// Filters the open vault as you type; the query never leaves the screen.
class _VaultSearchField extends StatelessWidget {
  const _VaultSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      // Typed searches aren't the keyboard's to learn from.
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      decoration: InputDecoration(
        hintText: strings.vaultSearch,
        prefixIcon: const Icon(AppIcons.search, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: strings.clearSearch,
                  onPressed: controller.clear,
                  icon: const Icon(AppIcons.close, size: 20),
                ),
        ),
      ),
    );
  }
}

/// What the Vault promises, in four lines.
class _VaultPromises extends StatelessWidget {
  const _VaultPromises();

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = [
      (AppIcons.fingerprint, strings.vaultHowLock),
      (AppIcons.lock, strings.vaultHowLocal),
      (AppIcons.visibilityOff, strings.vaultHowHidden),
      (AppIcons.error, strings.vaultHowLoss),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VaultRow extends StatelessWidget {
  const _VaultRow({
    required this.entry,
    required this.date,
    required this.onOpen,
    required this.onAction,
  });

  final VaultEntry entry;
  final String date;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final host = entry.host;
    final note = entry.note?.trim() ?? '';

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VaultMark(host: host),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    host.isEmpty ? date : '$host  ·  $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    // The note reads as the owner's own words, set off by
                    // a hairline rather than a box.
                    Container(
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: cs.primary.withValues(alpha: 0.45),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(AppIcons.more),
              tooltip: strings.itemActions,
              onSelected: onAction,
              itemBuilder: (context) => [
                appMenuItem(
                  value: 'copy',
                  icon: AppIcons.copy,
                  label: strings.copyLink,
                ),
                appMenuItem(
                  value: 'rename',
                  icon: AppIcons.edit,
                  label: strings.vaultRename,
                ),
                appMenuItem(
                  value: 'note',
                  icon: AppIcons.note,
                  label: note.isEmpty ? strings.addNote : strings.vaultEditNote,
                ),
                appMenuItem(
                  value: 'out',
                  icon: AppIcons.moveOut,
                  label: strings.vaultMoveOut,
                ),
                appMenuDivider,
                appMenuItem(
                  value: 'delete',
                  icon: AppIcons.deleteForever,
                  label: strings.delete,
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The site's own mark where Glimpse bundles one, else its initial: never
/// a fetched favicon, which would tell the site what's in the vault.
class _VaultMark extends StatelessWidget {
  const _VaultMark({required this.host});

  final String host;

  static String _platformName(String host) {
    final label = host.split('.').first;
    return switch (label) {
      'youtu' || 'm' when host.contains('youtu') => 'youtube',
      'twitter' => 'x',
      _ => label,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final platform = _platformName(host);
    final spec = resolveSourceIcon(platform);
    final initial = RegExp(
      r'[a-z0-9]',
      caseSensitive: false,
    ).firstMatch(host)?.group(0)?.toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: spec.isAsset || spec.isGlyph
          ? SourceLogo(name: platform, size: 24)
          : initial != null
          ? Text(
              initial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            )
          : AppIcon(AppIcons.link, size: 20, color: cs.onSecondaryContainer),
    );
  }
}
