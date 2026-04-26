import 'package:flutter_test/flutter_test.dart';
import 'package:admin_console/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminConsoleApp());
    expect(find.text('Admin Console Login'), findsOneWidget);
  });
}
