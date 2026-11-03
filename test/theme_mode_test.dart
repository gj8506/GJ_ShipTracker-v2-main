import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/theme/app_colors.dart';
import 'package:gjandasher_shiptracker/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppColors.applyBrightness(Brightness.light);
  });

  group('ThemeModeController', () {
    test('defaults to following the device', () async {
      final controller = ThemeModeController();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, ThemeMode.system);
      controller.dispose();
    });

    test('persists the chosen mode for the next launch', () async {
      final controller = ThemeModeController();
      await controller.setMode(ThemeMode.dark);
      expect(controller.state, ThemeMode.dark);

      final restored = ThemeModeController();
      await Future<void>.delayed(Duration.zero);
      expect(restored.state, ThemeMode.dark);

      controller.dispose();
      restored.dispose();
    });

    test('can go back to following the device', () async {
      final controller = ThemeModeController();
      await controller.setMode(ThemeMode.light);
      await controller.setMode(ThemeMode.system);
      expect(controller.state, ThemeMode.system);

      final restored = ThemeModeController();
      await Future<void>.delayed(Duration.zero);
      expect(restored.state, ThemeMode.system);

      controller.dispose();
      restored.dispose();
    });

    test('keeps the in-memory choice when storage is unavailable', () async {
      final controller = ThemeModeController();
      await controller.setMode(ThemeMode.dark);
      expect(controller.state, ThemeMode.dark);
      controller.dispose();
    });
  });

  group('AppColors palette', () {
    test('dark mode swaps surfaces and text colours', () {
      AppColors.applyBrightness(Brightness.light);
      final lightBackground = AppColors.backgroundLight;
      final lightSurface = AppColors.surfaceWhite;
      final lightText = AppColors.textPrimary;
      final lightBorder = AppColors.borderSubtle;

      AppColors.applyBrightness(Brightness.dark);

      expect(AppColors.isDark, isTrue);
      expect(AppColors.brightness, Brightness.dark);
      expect(AppColors.backgroundLight, isNot(lightBackground));
      expect(AppColors.surfaceWhite, isNot(lightSurface));
      expect(AppColors.textPrimary, isNot(lightText));
      expect(AppColors.borderSubtle, isNot(lightBorder));
    });

    test('switching back restores the light palette', () {
      AppColors.applyBrightness(Brightness.dark);
      final darkBackground = AppColors.backgroundLight;
      final darkText = AppColors.textPrimary;

      AppColors.applyBrightness(Brightness.light);

      expect(AppColors.isDark, isFalse);
      expect(AppColors.backgroundLight, isNot(darkBackground));
      expect(AppColors.textPrimary, isNot(darkText));
    });

    test('brand accents stay readable in both themes', () {
      AppColors.applyBrightness(Brightness.light);
      final lightAccent = AppColors.tealAccent;
      AppColors.applyBrightness(Brightness.dark);
      expect(AppColors.tealAccent, isNot(lightAccent));
    });
  });
}
