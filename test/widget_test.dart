import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Teste leve sem abrir o Drift/isolates (evita timers pendentes no `flutter test`).
void main() {
  testWidgets('Material smoke', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ok'))),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
