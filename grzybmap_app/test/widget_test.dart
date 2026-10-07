import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/main.dart';

void main() {
  testWidgets('GrzybMapApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GrzybMapApp());
    expect(find.byType(GrzybMapApp), findsOneWidget);
  });
}
