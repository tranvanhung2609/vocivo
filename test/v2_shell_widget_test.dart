import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocivo/core/theme/app_theme.dart';
import 'package:vocivo/screens/v2/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'V2 shell renders without overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const VocivoAppShell(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(VocivoAppShell), findsOneWidget);
        expect(find.text('Hôm nay'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('V2 shell supports mobile navigation at 125% text scale', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(1.25),
            ),
            child: VocivoAppShell(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Hôm nay'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
