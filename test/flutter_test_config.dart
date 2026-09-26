import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's Instrument Sans family (declared in pubspec `fonts`) so
/// golden tests render real text rather than placeholder boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('InstrumentSans');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/InstrumentSans-$weight.ttf').readAsBytes();
    loader.addFont(bytes.then((data) => ByteData.sublistView(data)));
  }
  await loader.load();
  await testMain();
}
