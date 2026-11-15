import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/theme/app_colors.dart';
import 'package:gjandasher_shiptracker/core/theme/app_theme.dart';

/// WCAG relative-luminance contrast ratio for two opaque colours.
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

  for (final brightness in Brightness.values) {
    group('$brightness palette', () {
      setUp(() => AppColors.applyBrightness(brightness));

      test('labels stay readable on brand and status surfaces', () {
        final pairs = <String, List<Color>>{
          'primary button label': [
            AppColors.textOnPrimary,
            AppColors.navyPrimary,
          ],
          'secondary button label': [
            AppColors.textOnPrimary,
            AppColors.navySecondary,
          ],
          'error button label': [
            AppColors.textOnPrimary,
            AppColors.errorRed,
          ],
          'success badge label': [
            AppColors.textOnPrimary,
            AppColors.statusDelivered,
          ],
          'pending badge label': [
            AppColors.textOnPrimary,
            AppColors.statusPending,
          ],
          'selected chip label': [
            AppColors.textOnPrimary,
            AppColors.navyPrimary,
          ],
          'callout banner text': [
            AppColors.onCallout,
            AppColors.calloutSurface,
          ],
          'hero banner text (left)': [
            AppColors.onCallout,
            AppColors.heroGradientStart,
          ],
          'hero banner text (right)': [
            AppColors.onCallout,
            AppColors.heroGradientEnd,
          ],
          'logo chip label': [
            AppColors.inkOnLight,
            AppColors.logoBlue,
          ],
          'body text on background': [
            AppColors.textPrimary,
            AppColors.backgroundLight,
          ],
          'secondary text on card': [
            AppColors.textSecondary,
            AppColors.surfaceWhite,
          ],
          'muted text on card': [
            AppColors.textMuted,
            AppColors.surfaceWhite,
          ],
          'navigation label': [
            AppColors.navyDark,
            AppColors.chromeBlue,
          ],
        };

        pairs.forEach((name, colors) {
          expect(
            _contrast(colors[0], colors[1]),
            greaterThanOrEqualTo(4.5),
            reason: '$name is unreadable in $brightness mode',
          );
        });
      });

      testWidgets('the installed theme wires the palette tokens',
          (tester) async {
        final theme = AppTheme.themeFor(brightness);

        expect(theme.colorScheme.onPrimary, AppColors.textOnPrimary);
        expect(theme.colorScheme.onError, AppColors.textOnPrimary);
        expect(theme.colorScheme.onInverseSurface, AppColors.textOnPrimary);
        expect(
          theme.floatingActionButtonTheme.foregroundColor,
          AppColors.textOnPrimary,
        );
        expect(
          theme.snackBarTheme.contentTextStyle?.color,
          AppColors.textOnPrimary,
        );
        expect(theme.snackBarTheme.actionTextColor, AppColors.textOnPrimary);
        expect(theme.tooltipTheme.textStyle?.color, AppColors.textOnPrimary);
        expect(theme.chipTheme.secondaryLabelStyle?.color,
            AppColors.textOnPrimary);
        expect(
          theme.checkboxTheme.checkColor?.resolve(const <WidgetState>{}),
          AppColors.textOnPrimary,
        );
        expect(
          theme.switchTheme.thumbColor
              ?.resolve(const <WidgetState>{WidgetState.selected}),
          AppColors.textOnPrimary,
        );
      });
    });
  }

  test('white labels are no longer used on light dark-mode surfaces', () {
    AppColors.applyBrightness(Brightness.dark);

    // Regression guard for the presentation bug: the dark palette turns the
    // brand blue into a light azure, so the label must stop being white.
    expect(AppColors.navyPrimary.computeLuminance(), greaterThan(0.3));
    expect(AppColors.textOnPrimary, isNot(Colors.white));
    expect(
      _contrast(AppColors.textOnPrimary, AppColors.navyPrimary),
      greaterThan(4.5),
    );
  });
}
