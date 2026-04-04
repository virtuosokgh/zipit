import 'package:flutter_test/flutter_test.dart';
import 'package:zipit/main.dart';

void main() {
  testWidgets('App launches', (tester) async {
    await tester.pumpWidget(const ZipitApp(onboardingCompleted: false));
    await tester.pump();
  });
}
