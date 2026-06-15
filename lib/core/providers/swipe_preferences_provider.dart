import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  /// Compact label used in tight surfaces like the swipe reveal.
  String get shortLabel {
    return switch (this) {
      SwipeActionType.toggleRead => 'Read',
      _ => label,
    };
  }

  IconData get icon {
    return switch (this) {
      SwipeActionType.delete => Icons.delete_outline_rounded,
      SwipeActionType.toggleRead => Icons.mark_email_read_outlined,
      SwipeActionType.addToCollection => Icons.create_new_folder_outlined,
      SwipeActionType.pin => Icons.push_pin_outlined,
      SwipeActionType.askGlimpse => Icons.auto_awesome_rounded,
      SwipeActionType.share => Icons.share_outlined,
      SwipeActionType.none => Icons.block_rounded,
    };
  }

  /// Renders the action glyph. Ask Glimpse uses the brand mark instead of a
  /// stock icon so it reads as a first-class, premium action everywhere.
  Widget iconWidget({required Color color, double size = 22}) {
    if (this == SwipeActionType.askGlimpse) {
      return SvgPicture.asset(
        'assets/glimpse.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(icon, size: size, color: color);
  }

  /// Muted, desaturated accents that read clearly during a swipe without
  /// fighting the app's calm dark surfaces.
  Color tint(ColorScheme colorScheme) {
    return switch (this) {
      SwipeActionType.delete => const Color(0xFFC78A8A),
      SwipeActionType.toggleRead => const Color(0xFF82A892),
      SwipeActionType.addToCollection => const Color(0xFF9C90C4),
      SwipeActionType.pin => const Color(0xFFCBB07E),
      SwipeActionType.askGlimpse => const Color(0xFF8AA4C8),
      SwipeActionType.share => const Color(0xFF8FA3B0),
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
      state = SwipePreferences(leftSwipeAction: left, rightSwipeAction: right);
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
