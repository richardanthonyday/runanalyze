import 'package:flutter_test/flutter_test.dart';

import 'package:runanalyze_mobile/main.dart';

void main() {
  testWidgets('app renders dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RunAnalyzeApp());

    expect(find.text('RunAnalyze (Basic)'), findsOneWidget);
  });
}
