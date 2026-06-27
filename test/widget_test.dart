import 'package:flutter_test/flutter_test.dart';
import 'package:kalyx_remote/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KalyxRemoteApp());
    expect(find.byType(KalyxRemoteApp), findsOneWidget);
  });
}
