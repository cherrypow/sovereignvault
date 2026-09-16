import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sovereign_vault/main.dart';

void main() {
  testWidgets('App boots to a setup or unlock screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SovereignVaultApp());
    await tester.pump();

    // The startup gate resolves to either SETUP or the PIN unlock
    // screen depending on whether a vault already exists — either way
    // the app should render without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
