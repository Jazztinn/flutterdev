import 'package:activity_hub/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens Activity 1', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('Activity 1'), findsOneWidget);
    expect(find.text('Activity 2'), findsOneWidget);

    await tester.tap(find.text('Activity 1'));
    await tester.pumpAndSettle();

    expect(
      find.text('This page is still under development. Please wait...'),
      findsOneWidget,
    );
  });
}
