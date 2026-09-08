import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/utils/theme.dart';

void main() {
  testWidgets('app theme is locked to light mode tokens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              platformBrightness: Brightness.light,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const Scaffold(body: Text('theme-lock')),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.light);

    final ctx = tester.element(find.text('theme-lock'));
    expect(Theme.of(ctx).brightness, Brightness.light);
    expect(Theme.of(ctx).colorScheme.primary, AppTheme.primary);
    expect(Theme.of(ctx).colorScheme.onPrimary, Colors.white);
    expect(MediaQuery.platformBrightnessOf(ctx), Brightness.light);
  });

  test('light color scheme uses teal branding with readable on-colors', () {
    final scheme = AppTheme.lightTheme.colorScheme;
    expect(scheme.primary, const Color(0xFF1A6B5A));
    expect(scheme.onPrimary, const Color(0xFFFFFFFF));
    expect(scheme.surface, const Color(0xFFFFFFFF));
    expect(scheme.onSurface, AppTheme.textPrimaryColor);
    expect(
        AppTheme.lightTheme.elevatedButtonTheme.style?.backgroundColor
            ?.resolve({}),
        AppTheme.primary);
  });
}
