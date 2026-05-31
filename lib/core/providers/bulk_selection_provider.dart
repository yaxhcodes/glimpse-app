import 'package:flutter_riverpod/flutter_riverpod.dart';

class BulkSelectionState {
  const BulkSelectionState({
    this.enabled = false,
    this.selectedIds = const <int>{},
  });

  final bool enabled;
  final Set<int> selectedIds;

  int get count => selectedIds.length;

  bool get isActive => enabled && selectedIds.isNotEmpty;

  bool isSelected(int id) => selectedIds.contains(id);

  BulkSelectionState copyWith({bool? enabled, Set<int>? selectedIds}) {
    return BulkSelectionState(
      enabled: enabled ?? this.enabled,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

final bulkSelectionProvider =
    StateNotifierProvider.family<
      BulkSelectionNotifier,
      BulkSelectionState,
      String
    >((ref, scope) {
      return BulkSelectionNotifier();
    });

class BulkSelectionNotifier extends StateNotifier<BulkSelectionState> {
  BulkSelectionNotifier() : super(const BulkSelectionState());

  void startWith(int id) {
    state = BulkSelectionState(enabled: true, selectedIds: {id});
  }

  void toggle(int id) {
    final selected = {...state.selectedIds};
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    state = BulkSelectionState(
      enabled: selected.isNotEmpty,
      selectedIds: selected,
    );
  }

  void selectAll(Iterable<int> ids) {
    final selected = ids.toSet();
    state = BulkSelectionState(
      enabled: selected.isNotEmpty,
      selectedIds: selected,
    );
  }

  void clear() {
    state = const BulkSelectionState();
  }

  void pruneToVisible(Iterable<int> visibleIds) {
    final visible = visibleIds.toSet();
    final selected = state.selectedIds.where(visible.contains).toSet();
    if (selected.length == state.selectedIds.length) return;
    state = BulkSelectionState(
      enabled: selected.isNotEmpty,
      selectedIds: selected,
    );
  }
}
