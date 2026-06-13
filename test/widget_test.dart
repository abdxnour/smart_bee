import 'package:flutter_test/flutter_test.dart';
import 'package:hive/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We use SmartBeeApp instead of the default MyApp after the refactor.
    await tester.pumpWidget(const SmartBeeApp());

    // Basic check to see if the app title or a key widget exists
    // Since Firebase is not initialized in the test environment, 
    // we expect at least the main widget to attempt to build.
    expect(find.byType(SmartBeeApp), findsOneWidget);
  });
}
