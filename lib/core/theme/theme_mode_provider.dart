import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the user's Light / Dark / System preference.
///
/// The value is stored as a short string so a future palette change cannot
/// break the saved setting. Anything unreadable falls back to
/// [ThemeMode.system], which is also the first-launch default so the app
/// matches the phone's own light/dark setting.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _restore();
  }

  static const String _storageKey = 'app.themeMode';

  /// Set once the user picks a mode, so a slow storage read can never overwrite
  /// a choice made while the app was starting up.
  bool _userSelected = false;

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restored = _decode(prefs.getString(_storageKey));
      if (!_userSelected && mounted && restored != state) {
        state = restored;
      }
    } catch (_) {
      // No storage plugin (e.g. widget tests): keep the system default.
    }
  }

  /// Applies [mode] immediately and saves it for the next launch.
  Future<void> setMode(ThemeMode mode) async {
    _userSelected = true;
    if (mode != state) {
      state = mode;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _encode(mode));
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});
