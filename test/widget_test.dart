import 'package:flutter_test/flutter_test.dart';

import 'package:cashlyze/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Cashlyze'), findsOneWidget);
  });
}
