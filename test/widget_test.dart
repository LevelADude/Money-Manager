// Basaler Smoke-Test.
//
// Die vollständige App benötigt eine initialisierte Supabase-Verbindung,
// daher prüfen wir hier nur, dass ein einfaches Widget rendert. Echte
// Integrationstests gegen Supabase gehören in integration_test/.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke: Text rendert', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Money Manager'))),
      ),
    );
    expect(find.text('Money Manager'), findsOneWidget);
  });
}
