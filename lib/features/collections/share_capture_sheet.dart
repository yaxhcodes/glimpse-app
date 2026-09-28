import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_haptics.dart';
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

/// How long "Saved to Reading" / "Note added" shows before closing.
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

typedef ShareCaptureCallback =
    Future<ShareCaptureOutcome> Function(
      UserCollection? collection,
      String? notes,
    );

/// Saves a shared link the moment it opens, then shows the "Saved to Glimpse"
/// pill with a collection and a note as optional edits. The pill gets out of
/// the way on its own; tapping anywhere else closes it at once (after the
/// save has landed).
Future<ShareCaptureOutcome?> showShareCapture(
  BuildContext context, {
  required ShareCaptureCallback onCapture,
  ShareCaptureCallback? onUpdate,
}) {
  return showGeneralDialog<ShareCaptureOutcome>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) =>
        _ShareCapture(onCapture: onCapture, onUpdate: onUpdate ?? onCapture),
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

enum _Panel { pill, collections, note }

class _ShareCapture extends ConsumerStatefulWidget {
  const _ShareCapture({required this.onCapture, required this.onUpdate});

  final ShareCaptureCallback onCapture;
  final ShareCaptureCallback onUpdate;

  @override
  ConsumerState<_ShareCapture> createState() => _ShareCaptureState();
}

class _ShareCaptureState extends ConsumerState<_ShareCapture> {
  final _noteController = TextEditingController();
  UserCollection? _collection;
  late final Future<UserCollection?> _defaultCollectionFuture;
  _Panel _panel = _Panel.pill;
  bool _capturing = false;
  bool _captureFailed = false;
  bool _editFailed = false;
  bool _closeWhenSaved = false;
  bool _closed = false;
  ShareCaptureOutcome? _outcome;
  String? _confirmation;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _defaultCollectionFuture = _prepareDefaultCollection();
    unawaited(_captureDefault());
  }

  @override
  void dispose() {
    _noteController.dispose();
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
    if (_capturing || !mounted) return;
    setState(() {
      _capturing = true;
      _captureFailed = false;
    });
    final collection = await _defaultCollectionFuture;
    if (!mounted) return;
    final outcome = await _run(widget.onCapture, collection, null);
    if (!mounted) return;
    if (!outcome.saved) {
      setState(() {
        _capturing = false;
        _captureFailed = true;
        _closeWhenSaved = false;
      });
      return;
    }
    AppHaptics.play(AppHaptics.success);
    setState(() {
      _outcome = outcome;
      _collection = collection;
      _capturing = false;
    });
    if (_closeWhenSaved) {
      _close();
    } else {
      _scheduleClose(_linger);
    }
  }

  /// Edits the save that already landed: [collection] moves it, [note] is
  /// appended. The confirmation shows briefly, then the pill closes.
  Future<void> _update({UserCollection? collection, String? note}) async {
    if (_capturing || _outcome == null || !mounted) return;
    final target = collection ?? _collection;
    setState(() {
      _capturing = true;
      _editFailed = false;
    });
    final outcome = await _run(widget.onUpdate, target, note);
    if (!mounted) return;
    if (!outcome.saved) {
      setState(() {
        _capturing = false;
        _editFailed = true;
        _closeWhenSaved = false;
      });
      return;
    }
    AppHaptics.play(AppHaptics.success);
    _noteController.clear();
    final strings = context.l10n;
    setState(() {
      _outcome = outcome;
      _collection = target;
      _capturing = false;
      _panel = _Panel.pill;
      _confirmation = collection != null
          ? strings.savedToCollection(collection.name)
          : strings.noteAdded;
    });
    if (_closeWhenSaved) {
      _close();
    } else {
      _scheduleClose(_confirmLinger);
    }
  }

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
    if (_capturing) {
      _closeWhenSaved = true;
      return;
    }
    final note = _noteController.text.trim();
    if (_panel == _Panel.note && note.isNotEmpty && _outcome != null) {
      _closeWhenSaved = true;
      unawaited(_update(note: note));
      return;
    }
    _closed = true;
    _closeTimer?.cancel();
    Navigator.of(context).pop(_outcome);
  }

  bool get _settledPill =>
      _panel == _Panel.pill && _outcome != null && !_capturing;

  void _hold() => _closeTimer?.cancel();

  void _release() {
    if (!_settledPill) return;
    _scheduleClose(_confirmation == null ? _linger : _confirmLinger);
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
    setState(() {
      _panel = _Panel.pill;
      _editFailed = false;
    });
    _scheduleClose(_linger);
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
    final saving = outcome == null && !_captureFailed;
    final title = _captureFailed
        ? strings.captureCouldNotSave
        : outcome == null
        ? strings.noteSaving
        : confirmation ??
              (outcome.type == ShareCaptureOutcomeType.duplicate
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
            if (saving)
              SizedBox.square(
                dimension: 26,
                child: Center(
                  child: ExpressiveLoadingIndicator(
                    size: 22,
                    color: colors.inversePrimary,
                    semanticsLabel: strings.noteSaving,
                  ),
                ),
              )
            else if (_captureFailed)
              SizedBox.square(
                dimension: 26,
                child: Icon(
                  AppIcons.error,
                  size: 22,
                  color: colors.onInverseSurface,
                ),
              )
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
                onPressed: _capturing ? null : _captureDefault,
              )
            else if (outcome != null && confirmation == null) ...[
              _PillAction(
                label: strings.collection,
                onPressed: () => _open(_Panel.collections),
              ),
              _PillAction(
                label: strings.note,
                onPressed: () => _open(_Panel.note),
              ),
            ] else if (confirmation != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AppIcon(
                  AppIcons.checkCircle,
                  size: 16,
                  color: colors.inversePrimary,
                ),
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
              enabled: !_capturing,
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
              enabled: !_capturing,
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
                    onPressed: _capturing || note.isEmpty
                        ? null
                        : () => _update(note: note),
                    child: _capturing
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
/// and the share pill.
class _CollectionChoices extends ConsumerWidget {
  const _CollectionChoices({
    required this.onSelected,
    this.allowNoCollection = false,
    this.selectedCollectionId,
    this.enabled = true,
  });

  final ValueChanged<CollectionPickerSelection> onSelected;
  final bool allowNoCollection;
  final int? selectedCollectionId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsListProvider);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (allowNoCollection) ...[
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
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : SizedBox(
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
                            ? Icon(
                                AppIcons.check,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () =>
                            onSelected(CollectionPickerSelection(collection)),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
