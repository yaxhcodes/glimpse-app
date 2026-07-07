import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glimpse/app.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GlimpseApp()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, contains('Glimpse'));
  });
}
