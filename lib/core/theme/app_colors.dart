import 'package:flutter/material.dart';

/// Central color system for GJandAsher ShipTracker.
///
/// The palette is sampled from `assets/images/GJandAsher_logo.jpg`:
///   • logo ring blue  — #00ADF1 (bright azure, decorative accents only)
///   • logo monogram   — #0F0FDF (royal blue, used very sparingly)
///
/// The visual balance follows a 75 / 20 / 5 rule:
///   • 75% — faint-white azure-tinted backgrounds that let content breathe.
///   • 20% — logo-blue interface elements (app bars, primary buttons, nav).
///   • 5%  — deep ink-blue text and small azure accents for emphasis.
///
/// Every token resolves against the active [Brightness], which the app root
/// sets before building the widget tree. That keeps one set of semantic names
/// working for both the light and the dark theme instead of duplicating the
/// palette in every screen.
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.light;

  /// Brightness the palette currently resolves against.
  static Brightness get brightness => _brightness;

  /// True when the dark palette is active.
  static bool get isDark => _brightness == Brightness.dark;

  /// Called by the app root (and by [AppTheme]) before a theme is built.
  static void applyBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static Color _pick(Color light, Color dark) => isDark ? dark : light;

  // ---------------------------------------------------------------------------
  // BRAND SOURCE (sampled directly from the GJandAsher logo)
  // ---------------------------------------------------------------------------
  /// Dominant ring blue from the logo. Bright: use for decoration, never as a
  /// background behind small white text.
  static const Color logoBlue = Color(0xFF00ADF1);

  /// Monogram royal blue from the logo. Reserved for rare, high-emphasis marks.
  static const Color logoRoyal = Color(0xFF0F0FDF);

  // ---------------------------------------------------------------------------
  // 75% — BACKGROUND & SURFACE (the dominant, calming layer)
  // ---------------------------------------------------------------------------
  static Color get backgroundLight =>
      _pick(const Color(0xFFF6FAFE), const Color(0xFF0A141D));
  static Color get backgroundElevated =>
      _pick(const Color(0xFFFCFEFF), const Color(0xFF0F1C27));
  static Color get surfaceWhite =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF13212E));
  static Color get surfaceMuted =>
      _pick(const Color(0xFFEDF4FA), const Color(0xFF172937));
  static Color get surfaceVariant =>
      _pick(const Color(0xFFE1EDF6), const Color(0xFF1E3446));
  static Color get background => backgroundLight;
  static Color get surface => surfaceWhite;

  // ---------------------------------------------------------------------------
  // 20% — INTERFACE, NAVIGATION & BUTTONS
  // ---------------------------------------------------------------------------
  static Color get navyPrimary =>
      _pick(const Color(0xFF0079AC), const Color(0xFF3AA7DA));
  static Color get navySecondary =>
      _pick(const Color(0xFF075E85), const Color(0xFF2F8FBE));
  static Color get navyDark =>
      _pick(const Color(0xFF0A4763), const Color(0xFFE7F2F9));
  static Color get navyMuted =>
      _pick(const Color(0xFF3E718C), const Color(0xFFA3BFD0));
  static Color get navyLight =>
      _pick(const Color(0xFF82AFC6), const Color(0xFF5B7C91));
  static Color get primary => navyPrimary;
  static Color get interface => navyPrimary;
  static Color get interfaceMuted => navySecondary;

  /// Light azure used for the app header and bottom navigation chrome.
  static Color get chromeBlue =>
      _pick(const Color(0xFFBEDEFF), const Color(0xFF0E1F2C));

  // Small accents (use sparingly — roughly 5% of the screen)
  static Color get tealAccent =>
      _pick(const Color(0xFF0093CE), const Color(0xFF45B8E8));
  static Color get tealSecondary =>
      _pick(const Color(0xFF6FD0F5), const Color(0xFF86D6F6));
  static Color get tealDark =>
      _pick(const Color(0xFF075E85), const Color(0xFF8FD5F1));
  static Color get tealContainer =>
      _pick(const Color(0xFFEAF8FE), const Color(0xFF113347));
  static Color get tealMuted =>
      _pick(const Color(0xFF82C6E0), const Color(0xFF4E87A0));

  /// Slightly deeper azure tint for selected navigation indicators and
  /// interactive surfaces that need to read clearly on white.
  static Color get accentSoft =>
      _pick(const Color(0xFFDCF2FD), const Color(0xFF14374C));
  static Color get accent => tealAccent;

  // ---------------------------------------------------------------------------
  // 5% — TEXT (high contrast, never pure black)
  // ---------------------------------------------------------------------------
  static Color get textPrimary =>
      _pick(const Color(0xFF0A2436), const Color(0xFFE9F3FA));
  static Color get textSecondary =>
      _pick(const Color(0xFF47657A), const Color(0xFFB3C9D8));
  static Color get textMuted =>
      _pick(const Color(0xFF5C7488), const Color(0xFF93AEBF));
  static const Color textOnPrimary = Colors.white;
  static const Color textOnDark = Color(0xFFF0F8FD);

  // ---------------------------------------------------------------------------
  // BORDERS & DIVIDERS
  // ---------------------------------------------------------------------------
  static Color get borderSubtle =>
      _pick(const Color(0xFFE4EEF6), const Color(0xFF1D3141));
  static Color get borderLight =>
      _pick(const Color(0xFFD4E4F0), const Color(0xFF294556));
  static Color get borderStrong =>
      _pick(const Color(0xFFBBD3E4), const Color(0xFF3A5B71));
  static Color get border => borderSubtle;

  // ---------------------------------------------------------------------------
  // PLATFORM BRAND COLORS
  // ---------------------------------------------------------------------------
  static const Color shopeeOrange = Color(0xFFEE4D2D);
  static Color get shopeeContainer =>
      _pick(const Color(0xFFFBEDEA), const Color(0xFF3B211B));
  static Color get lazadaBlue =>
      _pick(const Color(0xFF0F146D), const Color(0xFFA9B6FF));
  static Color get lazadaContainer =>
      _pick(const Color(0xFFE8EEF6), const Color(0xFF1C2440));
  static Color get tikTokBlack =>
      _pick(const Color(0xFF010101), const Color(0xFFE9F0F5));
  static Color get tikTokContainer =>
      _pick(const Color(0xFFEDF2F7), const Color(0xFF212B33));
  static Color get tiktokBlack => tikTokBlack;
  static Color get tiktokContainer => tikTokContainer;
  static const Color tikTokRed = Color(0xFFFE2C55);
  static const Color tikTokCyan = Color(0xFF25F4EE);

  // ---------------------------------------------------------------------------
  // PARCEL & RETURN STATUS COLORS (functional, semantic)
  // ---------------------------------------------------------------------------
  static Color get statusDelivered =>
      _pick(const Color(0xFF1E7A46), const Color(0xFF6FD6A1));
  static Color get statusDeliveredContainer =>
      _pick(const Color(0xFFE7F5EC), const Color(0xFF12301F));
  static Color get statusReturned =>
      _pick(const Color(0xFFC0392B), const Color(0xFFF58B7F));
  static Color get statusReturnedContainer =>
      _pick(const Color(0xFFFDECEC), const Color(0xFF3A1D1B));
  static Color get statusPending =>
      _pick(const Color(0xFFB26A00), const Color(0xFFF2BE6A));
  static Color get statusPendingContainer =>
      _pick(const Color(0xFFFFF4DB), const Color(0xFF36280F));
  static Color get statusInTransit =>
      _pick(const Color(0xFF0079AC), const Color(0xFF58BEEA));
  static Color get statusInTransitContainer =>
      _pick(const Color(0xFFEAF8FE), const Color(0xFF103040));
  static Color get statusDispatched =>
      _pick(const Color(0xFF0079AC), const Color(0xFF58BEEA));
  static Color get statusDispatchedContainer =>
      _pick(const Color(0xFFEAF8FE), const Color(0xFF103040));
  static Color get statusCancelled =>
      _pick(const Color(0xFF5F6B7A), const Color(0xFFA9B8C6));
  static Color get statusCancelledContainer =>
      _pick(const Color(0xFFEDF1F5), const Color(0xFF232F3A));
  static Color get statusApproved =>
      _pick(const Color(0xFF1E7A46), const Color(0xFF6FD6A1));
  static Color get statusReplacementDispatched =>
      _pick(const Color(0xFF6D28D9), const Color(0xFFC4A9FF));
  static Color get statusRefunded =>
      _pick(const Color(0xFF5B4B8A), const Color(0xFFBFAEE8));
  static Color get statusRejected =>
      _pick(const Color(0xFFC0392B), const Color(0xFFF58B7F));
  static Color get statusProcessing =>
      _pick(const Color(0xFF075E85), const Color(0xFF8FD5F1));
  static Color get statusFailed =>
      _pick(const Color(0xFFC0392B), const Color(0xFFF58B7F));

  // ---------------------------------------------------------------------------
  // SEMANTIC COLORS
  // ---------------------------------------------------------------------------
  static Color get successGreen =>
      _pick(const Color(0xFF1E7A46), const Color(0xFF6FD6A1));
  static Color get errorRed =>
      _pick(const Color(0xFFC0392B), const Color(0xFFF58B7F));
  static Color get warningOrange =>
      _pick(const Color(0xFFB26A00), const Color(0xFFF2BE6A));
  static Color get infoBlue =>
      _pick(const Color(0xFF0079AC), const Color(0xFF58BEEA));
  static Color get error => errorRed;
  static Color get success => successGreen;
  static Color get warning => warningOrange;
  static Color get info => infoBlue;

  // Supporting shades for semantic surfaces, borders and deep text.
  // These keep every screen inside the same 75 / 20 / 5 system.
  static Color get warningSurface =>
      _pick(const Color(0xFFFFF8E8), const Color(0xFF33280F));
  static Color get warningBorder =>
      _pick(const Color(0xFFF2D9A6), const Color(0xFF6B5324));
  static Color get warningDeep =>
      _pick(const Color(0xFF8A5200), const Color(0xFFF2C98A));
  static Color get warningDeepest =>
      _pick(const Color(0xFF6B3F00), const Color(0xFFF7DCAF));
  static Color get warningStrong =>
      _pick(const Color(0xFFB45309), const Color(0xFFF2BE6A));

  static Color get dangerDeep =>
      _pick(const Color(0xFF9B2C2C), const Color(0xFFF3A9A9));
  static Color get dangerBorder =>
      _pick(const Color(0xFFE7A9A9), const Color(0xFF6E3A3A));
  static Color get successBorder =>
      _pick(const Color(0xFFA7DDB8), const Color(0xFF2E6444));
  static Color get successDeep =>
      _pick(const Color(0xFF14532D), const Color(0xFFA6E8C2));

  static Color get tealBorder =>
      _pick(const Color(0xFFB7E2F5), const Color(0xFF24596E));
  static Color get borderCool =>
      _pick(const Color(0xFFD6E8F5), const Color(0xFF2B4A5E));

  static Color get textTertiary =>
      _pick(const Color(0xFF55707F), const Color(0xFF9DB6C6));
  static Color get textMutedAlt =>
      _pick(const Color(0xFF5C7488), const Color(0xFF93AEBF));
  static Color get purpleContainer =>
      _pick(const Color(0xFFEDE7F6), const Color(0xFF2B2545));

  // Microsoft Excel export branding (kept literal so the export action reads
  // instantly as "Excel" while still living in the palette).
  static const Color excelGreen = Color(0xFF107C41);
  static const Color excelGreenTint = Color(0x1F107C41);

  static Color get scrimLight =>
      _pick(const Color(0x14000000), const Color(0x33000000));
  static Color get scrimFaint =>
      _pick(const Color(0x06000000), const Color(0x1A000000));
}
