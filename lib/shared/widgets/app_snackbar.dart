import 'dart:async';

import 'package:flutter/material.dart';

/// Shows a [SnackBar] that is guaranteed to auto-dismiss after its
/// [SnackBar.duration], even when `MediaQuery.accessibleNavigation` is true.
///
/// In accessible-navigation mode Flutter's [ScaffoldMessenger] deliberately
/// skips the built-in auto-dismiss timer (so assistive-tech users have time to
/// act on the action), which on some devices/emulators leaves snackbars on
/// screen until the next one replaces them. We schedule an explicit close as a
/// backstop. If the snackbar was already dismissed (user tapped the action,
/// swiped it away, or a newer snackbar replaced it), [close] is a harmless
/// no-op, so this never affects a different snackbar.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAutoDismissSnackBar(
  BuildContext context,
  SnackBar snackBar,
) {
  return showAutoDismissSnackBarVia(ScaffoldMessenger.of(context), snackBar);
}

/// Variant for callers that already hold a [ScaffoldMessengerState] (e.g. one
/// captured before an `await` to avoid using a [BuildContext] across an async
/// gap). Behaves identically to [showAutoDismissSnackBar].
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAutoDismissSnackBarVia(
  ScaffoldMessengerState messenger,
  SnackBar snackBar,
) {
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(snackBar);
  Timer(snackBar.duration, controller.close);
  return controller;
}
