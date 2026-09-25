import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocivo/main.dart';

void main() {
  testWidgets('VocivoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VocivoApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(VocivoApp), findsOneWidget);
  });
}
