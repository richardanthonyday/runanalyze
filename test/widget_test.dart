import 'package:flutter_test/flutter_test.dart';

import 'package:runsimple_mobile/main.dart';

void main() {
  testWidgets('app renders dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RunSimpleApp());

    expect(find.text('runSimple'), findsOneWidget);
  });
}
