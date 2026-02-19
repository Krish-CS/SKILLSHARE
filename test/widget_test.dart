import 'package:flutter_test/flutter_test.dart';
import 'package:skillshare/main.dart';

void main() {
  testWidgets('App shows Firebase error fallback when initialization fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(firebaseInitialized: false));

    expect(find.text('Firebase Initialization Failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
