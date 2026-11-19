import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/theme/app_colors.dart';
import 'package:gjandasher_shiptracker/core/theme/app_theme.dart';

double _contrast(Color foreground, Color background) {
  final fg = foreground.computeLuminance();
  final bg = background.computeLuminance();
  final lighter = fg > bg ? fg : bg;
  final darker = fg > bg ? bg : fg;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppColors.applyBrightness(Brightness.light));

  testWidgets('light theme uses bold Cobalt for the header', (tester) async {
    final theme = AppTheme.themeFor(Brightness.light);

    expect(AppColors.navyPrimary, const Color(0xFF02569B));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF02569B));
    expect(theme.appBarTheme.titleTextStyle?.fontSize, 22);
    expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w700);
  });

  testWidgets(
      'bottom navigation is white in light mode and deep slate in dark mode',
      (tester) async {
    AppColors.applyBrightness(Brightness.light);
    expect(AppColors.chromeBlue, Colors.white);
    expect(AppColors.navIndicator, const Color(0xFFE0F2FE));

    final lightTheme = AppTheme.themeFor(Brightness.light);
    expect(lightTheme.navigationBarTheme.backgroundColor, Colors.white);
    expect(
      lightTheme.navigationBarTheme.indicatorColor,
      const Color(0xFFE0F2FE),
    );

    final darkTheme = AppTheme.themeFor(Brightness.dark);
    expect(darkTheme.navigationBarTheme.backgroundColor, AppColors.chromeBlue);
    expect(AppColors.chromeBlue, isNot(Colors.white));
    expect(
      darkTheme.navigationBarTheme.indicatorColor,
      const Color(0xFFE0F2FE),
    );

    // The selected icon sits on the soft-blue pill in both themes.
    for (final brightness in Brightness.values) {
      AppColors.applyBrightness(brightness);
      expect(
        _contrast(AppColors.navSelected, AppColors.navIndicator),
        greaterThanOrEqualTo(4.5),
        reason: 'the active navigation pill must stay readable in $brightness',
      );
    }
  });
}
