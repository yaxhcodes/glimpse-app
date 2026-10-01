import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/reminders/reminder_times.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/saved_toast.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';
import 'create_collection_sheet.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

const _defaultCollectionName = 'Inbox';

/// How long the saved pill stays before it gets out of the way.
const _linger = Duration(milliseconds: 2600);

/// How long the pill stays once both edits are done: nothing is left to
/// offer, so it only confirms.
const _confirmLinger = Duration(milliseconds: 1400);

const _morph = Duration(milliseconds: 280);

enum ShareCaptureOutcomeType { captured, duplicate, schedulingFallback, error }

class ShareCaptureOutcome {
  const ShareCaptureOutcome({
    required this.type,
    this.collectionName,
    this.notificationsEnabled = false,
    this.enrichmentPending = false,
    this.savedUrlId,
  });

  final ShareCaptureOutcomeType type;
  final String? collectionName;
  final bool notificationsEnabled;
  final bool enrichmentPending;
  final int? savedUrlId;

  bool get saved => type != ShareCaptureOutcomeType.error;
}

/// Why the pill can't save: it says so instead, with an optional way on.
class ShareCaptureBlock {
  const ShareCaptureBlock({required this.message, this.action, this.onAction});

  final String message;
  final String? action;
  final VoidCallback? onAction;
}

typedef ShareCaptureCallback =
    Future<ShareCaptureOutcome> Function(
      UserCollection? collection,
      String? notes,
    );

typedef ShareCaptureRename = Future<ShareCaptureOutcome> Function(String name);

typedef ShareCaptureRemind =
    Future<ShareCaptureOutcome> Function(DateTime at);

/// Saves a shared link the moment it opens, then shows the "Saved to Glimpse"
/// pill with a collection and a note as optional edits. The pill gets out of
/// the way on its own; tapping anywhere else closes it at once (after the
/// save has landed).
///
/// [vault] files into the Vault instead: a lock, and a name ([onRename])
/// and a note as the edits, since nothing names a vault item but its owner.
/// [block] shows why nothing can be saved, and saves nothing.
Future<ShareCaptureOutcome?> showShareCapture(
  BuildContext context, {
  required ShareCaptureCallback onCapture,
  ShareCaptureCallback? onUpdate,
  ShareCaptureRename? onRename,
  ShareCaptureRemind? onRemind,
  bool vault = false,
  ShareCaptureBlock? block,
}) {
  return showGeneralDialog<ShareCaptureOutcome>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => _ShareCapture(
      onCapture: onCapture,
      onUpdate: onUpdate ?? onCapture,
      onRename: onRename,
      onRemind: onRemind,
      vault: vault,
      block: block,
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .12),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

enum _Panel { pill, collections, note, name, remind }

class _ShareCapture extends ConsumerStatefulWidget {
  const _ShareCapture({
    required this.onCapture,
    required this.onUpdate,
    this.onRename,
    this.onRemind,
    this.vault = false,
    this.block,
  });

  final ShareCaptureCallback onCapture;
  final ShareCaptureCallback onUpdate;
  final ShareCaptureRename? onRename;

  /// Offers Remind when set: the reminder lands on the save just made.
  final ShareCaptureRemind? onRemind;
  final bool vault;
  final ShareCaptureBlock? block;

  @override
  ConsumerState<_ShareCapture> createState() => _ShareCaptureState();
}

class _ShareCaptureState extends ConsumerState<_ShareCapture> {
  final _noteController = TextEditingController();
  final _nameController = TextEditingController();
  UserCollection? _collection;
  late final Future<UserCollection?> _defaultCollectionFuture;
  _Panel _panel = _Panel.pill;

  /// The shared link's own save, in flight. The pill already reads as saved
  /// (it's a local write); edits wait on [_landed] before applying.
  bool _saving = false;
  Future<bool>? _landed;

  /// A collection or note edit, in flight.
  bool _editing = false;
  bool _captureFailed = false;
  bool _editFailed = false;
  bool _closeWhenSaved = false;
  bool _closed = false;
  ShareCaptureOutcome? _outcome;
  String? _confirmation;
  // In the Vault there are no collections; this slot is the name instead.
  late bool _filed = widget.vault && widget.onRename == null;
  bool _noted = false;
  late bool _reminded = widget.onRemind == null;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _defaultCollectionFuture = widget.vault
        ? Future.value(null)
        : _prepareDefaultCollection();
    if (widget.block == null) {
      unawaited(_captureDefault());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleClose(_linger);
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _nameController.dispose();
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<UserCollection?> _prepareDefaultCollection() async {
    try {
      final isar = ref.read(isarServiceProvider);
      final collections = await isar.getAllCollections();
      for (final collection in collections) {
        if (collection.name.trim().toLowerCase() ==
            _defaultCollectionName.toLowerCase()) {
          return collection;
        }
      }
      return null;
    } catch (error, stackTrace) {
      developer.log(
        'Could not prepare the default share collection.',
        name: 'ShareCapture',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<ShareCaptureOutcome> _run(
    ShareCaptureCallback callback,
    UserCollection? collection,
    String? note,
  ) async {
    try {
      return await callback(collection, note);
    } catch (error, stackTrace) {
      developer.log(
        'Share capture failed.',
        name: 'ShareCapture',
        error: error,
        stackTrace: stackTrace,
      );
      return const ShareCaptureOutcome(type: ShareCaptureOutcomeType.error);
    }
  }

  Future<void> _captureDefault() async {
    if (_saving || !mounted) return;
    final landed = Completer<bool>();
    _landed = landed.future;
    setState(() {
      _saving = true;
      _captureFailed = false;
    });
    final collection = await _defaultCollectionFuture;
    if (!mounted) return;
    _collection = collection;
    if (_panel == _Panel.pill) _scheduleClose(_lingerNow);
    final outcome = await _run(widget.onCapture, collection, null);
    if (!mounted) return;
    landed.complete(outcome.saved);
    if (!outcome.saved) {
      _closeTimer?.cancel();
      setState(() {
        _saving = false;
        _captureFailed = true;
        _closeWhenSaved = false;
        _panel = _Panel.pill;
      });
      return;
    }
    AppHaptics.play(AppHaptics.success);
    setState(() {
      _outcome = outcome;
      _saving = false;
    });
    if (_closeWhenSaved) _close();
  }

  /// Edits the save that already landed: [collection] moves it (or, in the
  /// Vault, [name] names it), [note] is appended. The pill comes back
  /// confirming it, still offering whichever edit hasn't been made.
  Future<void> _update({
    UserCollection? collection,
    String? note,
    String? name,
    DateTime? remindAt,
  }) async {
    final landed = _landed;
    if (_editing || landed == null || !mounted) return;
    setState(() {
      _editing = true;
      _editFailed = false;
    });
    // An edit made before the link's own save lands waits for it; if that
    // save fails, the pill already says so and offers Retry.
    if (!await landed || !mounted) {
      if (mounted) setState(() => _editing = false);
      return;
    }
    final target = collection ?? _collection;
    final rename = widget.onRename;
    final remind = widget.onRemind;
    final outcome = remindAt != null && remind != null
        ? await _run((_, _) => remind(remindAt), null, null)
        : name != null && rename != null
        ? await _run((_, _) => rename(name), null, null)
        : await _run(widget.onUpdate, target, note);
    if (!mounted) return;
    if (!outcome.saved) {
      setState(() {
        _editing = false;
        _editFailed = true;
        _closeWhenSaved = false;
      });
      return;
    }
    AppHaptics.play(AppHaptics.success);
    _noteController.clear();
    _nameController.clear();
    final strings = context.l10n;
    setState(() {
      _outcome = outcome;
      _collection = target;
      _editing = false;
      _panel = _Panel.pill;
      if (collection != null || name != null) _filed = true;
      if (note != null) _noted = true;
      if (remindAt != null) _reminded = true;
      _confirmation = remindAt != null
          ? strings.reminderSetFor(
              formatReminderWhen(
                strings,
                Localizations.localeOf(context).toLanguageTag(),
                remindAt,
              ),
            )
          : name != null
          ? strings.vaultNamedAs(name)
          : collection != null
          ? strings.savedToCollection(collection.name)
          : strings.noteAdded;
    });
    if (_closeWhenSaved) {
      _close();
    } else {
      _scheduleClose(_lingerNow);
    }
  }

  bool get _allDone => _filed && _noted && _reminded;

  Duration get _lingerNow => _allDone ? _confirmLinger : _linger;

  void _scheduleClose(Duration delay) {
    _closeTimer?.cancel();
    // Screen-reader users close it themselves; a timer would cut them off.
    if (MediaQuery.accessibleNavigationOf(context)) return;
    _closeTimer = Timer(delay, _close);
  }

  /// Closes once nothing is left in flight. A note that was typed but not
  /// saved is saved on the way out rather than thrown away.
  void _close() {
    if (_closed || !mounted) return;
    if (_saving || _editing) {
      _closeWhenSaved = true;
      return;
    }
    final note = _noteController.text.trim();
    if (_panel == _Panel.note && note.isNotEmpty && !_captureFailed) {
      _closeWhenSaved = true;
      unawaited(_update(note: note));
      return;
    }
    final name = _nameController.text.trim();
    if (_panel == _Panel.name && name.isNotEmpty && !_captureFailed) {
      _closeWhenSaved = true;
      unawaited(_update(name: name));
      return;
    }
    _closed = true;
    _closeTimer?.cancel();
    Navigator.of(context).pop(_outcome);
  }

  bool get _settledPill =>
      _panel == _Panel.pill && !_captureFailed && !_editing;

  void _hold() => _closeTimer?.cancel();

  void _release() {
    if (!_settledPill) return;
    _scheduleClose(_lingerNow);
  }

  void _open(_Panel panel) {
    _closeTimer?.cancel();
    setState(() {
      _panel = panel;
      _editFailed = false;
    });
  }

  void _backToPill() {
    _noteController.clear();
    _nameController.clear();
    setState(() {
      _panel = _Panel.pill;
      _editFailed = false;
    });
    _scheduleClose(_lingerNow);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_panel == _Panel.pill) {
          _close();
        } else {
          _backToPill();
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // The app the link came from stays visible; touching it closes.
            Positioned.fill(
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Listener(
                      onPointerDown: (_) => _hold(),
                      onPointerUp: (_) => _release(),
                      onPointerCancel: (_) => _release(),
                      child: GestureDetector(
                        onVerticalDragEnd: _panel == _Panel.pill
                            ? (details) {
                                if ((details.primaryVelocity ?? 0) > 300) {
                                  _close();
                                }
                              }
                            : null,
                        child: _surface(context),
                      ),
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

  Widget _surface(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final expanded = _panel != _Panel.pill;
    return AnimatedContainer(
      duration: _morph,
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: savedToastDecoration(
        colors,
        color: expanded ? colors.surfaceContainerHigh : null,
        radius: 28,
      ),
      child: AnimatedSize(
        duration: _morph,
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_panel) {
            _Panel.pill => _pill(context),
            _Panel.collections => _collectionsPanel(context),
            _Panel.note => _notePanel(context),
            _Panel.name => _namePanel(context),
            _Panel.remind => _remindPanel(context),
          },
        ),
      ),
    );
  }

  Widget _pill(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.l10n;
    final outcome = _outcome;
    final confirmation = _confirmation;
    final block = widget.block;
    if (block != null) return _blockedPill(context, block);
    final title = _captureFailed
        ? (widget.vault
              ? strings.vaultCouldNotSave
              : strings.captureCouldNotSave)
        : confirmation ??
              (widget.vault
                  ? strings.savedToVault
                  : outcome?.type == ShareCaptureOutcomeType.duplicate
                  ? strings.alreadyInGlimpse
                  : strings.savedToGlimpse);

    return ConstrainedBox(
      key: const ValueKey('pill'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_captureFailed)
              SizedBox.square(
                dimension: 26,
                child: Icon(
                  AppIcons.error,
                  size: 22,
                  color: colors.onInverseSurface,
                ),
              )
            else if (widget.vault)
              _VaultGlyph(color: colors.inversePrimary)
            else
              const SavedToastIcon(),
            const SizedBox(width: 10),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onInverseSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (_captureFailed)
              _PillAction(
                label: strings.retry,
                onPressed: _saving ? null : _captureDefault,
              )
            else if (!_allDone) ...[
              if (!_filed)
                _PillAction(
                  label: widget.vault ? strings.vaultName : strings.collection,
                  onPressed: () =>
                      _open(widget.vault ? _Panel.name : _Panel.collections),
                ),
              if (!_noted)
                _PillAction(
                  label: strings.note,
                  onPressed: () => _open(_Panel.note),
                ),
              // A bell, not a word: three words would crowd out "Saved to
              // Glimpse".
              if (!_reminded)
                IconButton(
                  tooltip: strings.remindMe,
                  onPressed: () => _open(_Panel.remind),
                  style: IconButton.styleFrom(
                    foregroundColor: colors.inversePrimary,
                    minimumSize: const Size(40, 44),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const StadiumBorder(),
                  ),
                  icon: const AppIcon(AppIcons.notifications, size: 20),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AppIcon(
                  AppIcons.checkCircle,
                  size: 16,
                  color: colors.inversePrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _blockedPill(BuildContext context, ShareCaptureBlock block) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final onAction = block.onAction;
    return ConstrainedBox(
      key: const ValueKey('blocked'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _VaultGlyph(color: colors.inversePrimary),
            const SizedBox(width: 10),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  block.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onInverseSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (block.action != null && onAction != null)
              _PillAction(
                label: block.action!,
                onPressed: () {
                  _close();
                  onAction();
                },
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _collectionsPanel(BuildContext context) {
    return Padding(
      key: const ValueKey('collections'),
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: context.l10n.addToCollection,
            onClose: _backToPill,
          ),
          if (_editFailed) const _EditFailed(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CollectionChoices(
              selectedCollectionId: _collection?.id,
              enabled: !_editing,
              onSelected: (selection) {
                final collection = selection.collection;
                if (collection != null) {
                  unawaited(_update(collection: collection));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _remindPanel(BuildContext context) {
    final strings = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final presets = reminderPresets(reminderNow());
    return Padding(
      key: const ValueKey('remind'),
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(title: strings.remindMe, onClose: _backToPill),
          if (_editFailed) const _EditFailed(),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (preset, at) in presets)
                  ActionChip(
                    label: Text(
                      '${reminderPresetLabel(strings, preset)} · '
                      '${reminderPresetTime(locale, preset, at)}',
                    ),
                    onPressed: _editing
                        ? null
                        : () => unawaited(_update(remindAt: at)),
                  ),
                ActionChip(
                  avatar: const Icon(AppIcons.calendar, size: 18),
                  label: Text(strings.reminderPickTime),
                  onPressed: _editing ? null : _pickReminderTime,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReminderTime() async {
    final now = reminderNow();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!at.isAfter(reminderNow())) {
      setState(() => _editFailed = true);
      return;
    }
    await _update(remindAt: at);
  }

  Widget _namePanel(BuildContext context) {
    final strings = context.l10n;
    return Padding(
      key: const ValueKey('name'),
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: strings.vaultNamePanelTitle,
            onClose: _backToPill,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextField(
              controller: _nameController,
              autofocus: true,
              enabled: !_editing,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                final name = value.trim();
                if (name.isNotEmpty) unawaited(_update(name: name));
              },
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          if (_editFailed) const _EditFailed(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (context, value, _) {
                  final name = value.text.trim();
                  return FilledButton(
                    onPressed: _editing || name.isEmpty
                        ? null
                        : () => _update(name: name),
                    child: _editing
                        ? const ExpressiveLoadingIndicator(size: 18)
                        : Text(strings.save),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notePanel(BuildContext context) {
    final strings = context.l10n;
    return Padding(
      key: const ValueKey('note'),
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(title: strings.addNote, onClose: _backToPill),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextField(
              controller: _noteController,
              autofocus: true,
              enabled: !_editing,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          if (_editFailed) const _EditFailed(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _noteController,
                builder: (context, value, _) {
                  final note = value.text.trim();
                  return FilledButton(
                    onPressed: _editing || note.isEmpty
                        ? null
                        : () => _update(note: note),
                    child: _editing
                        ? const ExpressiveLoadingIndicator(size: 18)
                        : Text(strings.save),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Vault's mark on the pill, where a save shows the app icon.
class _VaultGlyph extends StatelessWidget {
  const _VaultGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 26,
      child: Center(
        child: AppIcon(AppIcons.lock, size: 20, filled: true, color: color),
      ),
    );
  }
}

/// A snackbar-style text action on the dark pill.
class _PillAction extends StatelessWidget {
  const _PillAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.inversePrimary,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          tooltip: context.l10n.cancel,
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    );
  }
}

class _EditFailed extends StatelessWidget {
  const _EditFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        context.l10n.saveEditFailed,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

Future<UserCollection?> showCollectionPickerSheet(BuildContext context) {
  return _showCollectionPickerSheet(
    context,
  ).then((selection) => selection?.collection);
}

class CollectionPickerSelection {
  const CollectionPickerSelection(this.collection);

  final UserCollection? collection;
}

Future<CollectionPickerSelection?> showOptionalCollectionPickerSheet(
  BuildContext context, {
  int? selectedCollectionId,
}) {
  return _showCollectionPickerSheet(
    context,
    allowNoCollection: true,
    selectedCollectionId: selectedCollectionId,
  );
}

Future<CollectionPickerSelection?> _showCollectionPickerSheet(
  BuildContext context, {
  bool allowNoCollection = false,
  int? selectedCollectionId,
}) {
  return showModalBottomSheet<CollectionPickerSelection>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CollectionPickerSheet(
      allowNoCollection: allowNoCollection,
      selectedCollectionId: selectedCollectionId,
    ),
  );
}

class _CollectionPickerSheet extends StatelessWidget {
  const _CollectionPickerSheet({
    required this.allowNoCollection,
    this.selectedCollectionId,
  });

  final bool allowNoCollection;
  final int? selectedCollectionId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.chooseCollection,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _CollectionChoices(
              allowNoCollection: allowNoCollection,
              searchable: true,
              selectedCollectionId: selectedCollectionId,
              onSelected: (selection) => Navigator.of(context).pop(selection),
            ),
          ],
        ),
      ),
    );
  }
}

/// "New collection" plus the user's collections, shared by the picker sheet
/// and the share pill. The sheet can search a long list by name.
class _CollectionChoices extends ConsumerStatefulWidget {
  const _CollectionChoices({
    required this.onSelected,
    this.allowNoCollection = false,
    this.selectedCollectionId,
    this.enabled = true,
    this.searchable = false,
  });

  final ValueChanged<CollectionPickerSelection> onSelected;
  final bool allowNoCollection;
  final int? selectedCollectionId;
  final bool enabled;
  final bool searchable;

  @override
  ConsumerState<_CollectionChoices> createState() => _CollectionChoicesState();
}

class _CollectionChoicesState extends ConsumerState<_CollectionChoices> {
  /// Below this many collections the whole list fits and search is noise.
  static const _searchThreshold = 7;

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsListProvider);
    final theme = Theme.of(context);
    final enabled = widget.enabled;
    final onSelected = widget.onSelected;
    final selectedCollectionId = widget.selectedCollectionId;
    final showSearch =
        widget.searchable &&
        (collections.valueOrNull?.length ?? 0) >= _searchThreshold;
    final query = _query.trim().toLowerCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSearch) ...[
          TextField(
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: context.l10n.searchCollections,
              prefixIcon: const Icon(AppIcons.search, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (query.isEmpty) ...[
          FilledButton.tonalIcon(
            onPressed: enabled
                ? () async {
                    final collection = await showCreateCollectionSheet(context);
                    if (collection != null && context.mounted) {
                      onSelected(CollectionPickerSelection(collection));
                    }
                  }
                : null,
            icon: const Icon(AppIcons.add),
            label: Text(context.l10n.newCollection),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.allowNoCollection && query.isEmpty) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: enabled,
            leading: Icon(
              AppIcons.folderOff,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(context.l10n.noCollection),
            trailing: selectedCollectionId == null
                ? Icon(AppIcons.check, color: theme.colorScheme.primary)
                : null,
            onTap: () => onSelected(const CollectionPickerSelection(null)),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
        ],
        collections.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: ExpressiveLoadingIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.couldNotLoadCollections),
          ),
          data: (all) {
            final items = query.isEmpty
                ? all
                : [
                    for (final c in all)
                      if (c.name.toLowerCase().contains(query)) c,
                  ];
            if (items.isEmpty) {
              return query.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        context.l10n.noCollectionsMatch,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
            }
            return SizedBox(
              height: (items.length * 56.0).clamp(56, 336),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final collection = items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: enabled,
                    leading: CollectionVisual(
                      style: resolveCollectionVisual(collection),
                      size: 40,
                      iconSize: 18,
                    ),
                    title: Text(collection.name),
                    subtitle: Text(
                      context.l10n.linkCount(collection.urlIds.length),
                    ),
                    trailing: selectedCollectionId == collection.id
                        ? Icon(AppIcons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () =>
                        onSelected(CollectionPickerSelection(collection)),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
