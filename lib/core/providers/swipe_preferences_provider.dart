import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLeftSwipeActionKey = 'glimpse_left_swipe_action';
const _kRightSwipeActionKey = 'glimpse_right_swipe_action';

enum SwipeActionType {
  delete,
  toggleRead,
  addToCollection,
  pin,
  askGlimpse,
  share,
  none,
}

extension SwipeActionTypeInfo on SwipeActionType {
  String get label {
    return switch (this) {
      SwipeActionType.delete => 'Delete',
      SwipeActionType.toggleRead => 'Mark Read / Unread',
      SwipeActionType.addToCollection => 'Add to Collection',
      SwipeActionType.pin => 'Pin',
      SwipeActionType.askGlimpse => 'Ask Glimpse',
      SwipeActionType.share => 'Share',
      SwipeActionType.none => 'None',
    };
  }

  IconData get icon {
    return switch (this) {
      SwipeActionType.delete => Icons.delete_outline_rounded,
      SwipeActionType.toggleRead => Icons.mark_email_read_outlined,
      SwipeActionType.addToCollection => Icons.collections_bookmark_outlined,
      SwipeActionType.pin => Icons.push_pin_outlined,
      SwipeActionType.askGlimpse => Icons.auto_awesome_rounded,
      SwipeActionType.share => Icons.share_outlined,
      SwipeActionType.none => Icons.block_rounded,
    };
  }

  Color tint(ColorScheme colorScheme) {
    return switch (this) {
      SwipeActionType.delete => colorScheme.error,
      SwipeActionType.toggleRead => const Color(0xFF27AE60),
      SwipeActionType.addToCollection => const Color(0xFF8E6AD8),
      SwipeActionType.pin => const Color(0xFFE0A526),
      SwipeActionType.askGlimpse => const Color(0xFF4C8DFF),
      SwipeActionType.share => colorScheme.primary,
      SwipeActionType.none => colorScheme.outline,
    };
  }
}

class SwipePreferences {
  const SwipePreferences({
    required this.leftSwipeAction,
    required this.rightSwipeAction,
  });

  final SwipeActionType leftSwipeAction;
  final SwipeActionType rightSwipeAction;

  SwipePreferences copyWith({
    SwipeActionType? leftSwipeAction,
    SwipeActionType? rightSwipeAction,
  }) {
    return SwipePreferences(
      leftSwipeAction: leftSwipeAction ?? this.leftSwipeAction,
      rightSwipeAction: rightSwipeAction ?? this.rightSwipeAction,
    );
  }
}

final swipePreferencesProvider =
    StateNotifierProvider<SwipePreferencesNotifier, SwipePreferences>((ref) {
  return SwipePreferencesNotifier();
});

class SwipePreferencesNotifier extends StateNotifier<SwipePreferences> {
  SwipePreferencesNotifier()
      : super(
          const SwipePreferences(
            leftSwipeAction: SwipeActionType.delete,
            rightSwipeAction: SwipeActionType.addToCollection,
          ),
        ) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final left = _decode(
      prefs.getString(_kLeftSwipeActionKey),
      fallback: SwipeActionType.delete,
    );
    final right = _decode(
      prefs.getString(_kRightSwipeActionKey),
      fallback: SwipeActionType.addToCollection,
    );
    if (mounted) {
      state = SwipePreferences(
        leftSwipeAction: left,
        rightSwipeAction: right,
      );
    }
  }

  Future<void> setLeft(SwipeActionType action) async {
    state = state.copyWith(leftSwipeAction: action);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLeftSwipeActionKey, action.name);
  }

  Future<void> setRight(SwipeActionType action) async {
    state = state.copyWith(rightSwipeAction: action);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRightSwipeActionKey, action.name);
  }

  static SwipeActionType _decode(
    String? raw, {
    required SwipeActionType fallback,
  }) {
    if (raw == null) return fallback;
    for (final action in SwipeActionType.values) {
      if (action.name == raw) return action;
    }
    return fallback;
  }
}
