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
/// Keeping the tokens here means both the Admin/Staff experience and the
/// Customer Portal share one consistent, professional visual language.
class AppColors {
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
  static const Color backgroundLight = Color(0xFFF6FAFE);
  static const Color backgroundElevated = Color(0xFFFCFEFF);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF4FA);
  static const Color surfaceVariant = Color(0xFFE1EDF6);
  static const Color background = backgroundLight;
  static const Color surface = surfaceWhite;

  // ---------------------------------------------------------------------------
  // 20% — INTERFACE, NAVIGATION & BUTTONS
  // ---------------------------------------------------------------------------
  static const Color navyPrimary = Color(0xFF0079AC);
  static const Color navySecondary = Color(0xFF075E85);
  static const Color navyDark = Color(0xFF0A4763);
  static const Color navyMuted = Color(0xFF3E718C);
  static const Color navyLight = Color(0xFF82AFC6);
  static const Color primary = navyPrimary;
  static const Color interface = navyPrimary;
  static const Color interfaceMuted = navySecondary;

  /// Light azure used for the app header and bottom navigation chrome.
  static const Color chromeBlue = Color(0xFFBEDEFF);

  // Small accents (use sparingly — roughly 5% of the screen)
  static const Color tealAccent = Color(0xFF0093CE);
  static const Color tealSecondary = Color(0xFF6FD0F5);
  static const Color tealDark = Color(0xFF075E85);
  static const Color tealContainer = Color(0xFFEAF8FE);
  static const Color tealMuted = Color(0xFF82C6E0);

  /// Slightly deeper azure tint for selected navigation indicators and
  /// interactive surfaces that need to read clearly on white.
  static const Color accentSoft = Color(0xFFDCF2FD);
  static const Color accent = tealAccent;

  // ---------------------------------------------------------------------------
  // 5% — TEXT (high contrast, never pure black)
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF0A2436);
  static const Color textSecondary = Color(0xFF47657A);
  static const Color textMuted = Color(0xFF5C7488);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnDark = Color(0xFFF0F8FD);

  // ---------------------------------------------------------------------------
  // BORDERS & DIVIDERS
  // ---------------------------------------------------------------------------
  static const Color borderSubtle = Color(0xFFE4EEF6);
  static const Color borderLight = Color(0xFFD4E4F0);
  static const Color borderStrong = Color(0xFFBBD3E4);
  static const Color border = borderSubtle;

  // ---------------------------------------------------------------------------
  // PLATFORM BRAND COLORS
  // ---------------------------------------------------------------------------
  static const Color shopeeOrange = Color(0xFFEE4D2D);
  static const Color shopeeContainer = Color(0xFFFBEDEA);
  static const Color lazadaBlue = Color(0xFF0F146D);
  static const Color lazadaContainer = Color(0xFFE8EEF6);
  static const Color tikTokBlack = Color(0xFF010101);
  static const Color tikTokContainer = Color(0xFFEDF2F7);
  static const Color tiktokBlack = Color(0xFF010101);
  static const Color tiktokContainer = Color(0xFFEDF2F7);
  static const Color tikTokRed = Color(0xFFFE2C55);
  static const Color tikTokCyan = Color(0xFF25F4EE);

  // ---------------------------------------------------------------------------
  // PARCEL & RETURN STATUS COLORS (functional, semantic)
  // ---------------------------------------------------------------------------
  static const Color statusDelivered = Color(0xFF1E7A46);
  static const Color statusDeliveredContainer = Color(0xFFE7F5EC);
  static const Color statusReturned = Color(0xFFC0392B);
  static const Color statusReturnedContainer = Color(0xFFFDECEC);
  static const Color statusPending = Color(0xFFB26A00);
  static const Color statusPendingContainer = Color(0xFFFFF4DB);
  static const Color statusInTransit = Color(0xFF0079AC);
  static const Color statusInTransitContainer = Color(0xFFEAF8FE);
  static const Color statusDispatched = Color(0xFF0079AC);
  static const Color statusDispatchedContainer = Color(0xFFEAF8FE);
  static const Color statusCancelled = Color(0xFF5F6B7A);
  static const Color statusCancelledContainer = Color(0xFFEDF1F5);
  static const Color statusApproved = Color(0xFF1E7A46);
  static const Color statusReplacementDispatched = Color(0xFF6D28D9);
  static const Color statusRefunded = Color(0xFF5B4B8A);
  static const Color statusRejected = Color(0xFFC0392B);
  static const Color statusProcessing = Color(0xFF075E85);
  static const Color statusFailed = Color(0xFFC0392B);

  // ---------------------------------------------------------------------------
  // SEMANTIC COLORS
  // ---------------------------------------------------------------------------
  static const Color successGreen = Color(0xFF1E7A46);
  static const Color errorRed = Color(0xFFC0392B);
  static const Color warningOrange = Color(0xFFB26A00);
  static const Color infoBlue = Color(0xFF0079AC);
  static const Color error = errorRed;
  static const Color success = successGreen;
  static const Color warning = warningOrange;
  static const Color info = infoBlue;

  // Supporting shades for semantic surfaces, borders and deep text.
  // These keep every screen inside the same 75 / 20 / 5 system.
  static const Color warningSurface = Color(0xFFFFF8E8);
  static const Color warningBorder = Color(0xFFF2D9A6);
  static const Color warningDeep = Color(0xFF8A5200);
  static const Color warningDeepest = Color(0xFF6B3F00);
  static const Color warningStrong = Color(0xFFB45309);

  static const Color dangerDeep = Color(0xFF9B2C2C);
  static const Color dangerBorder = Color(0xFFE7A9A9);
  static const Color successBorder = Color(0xFFA7DDB8);
  static const Color successDeep = Color(0xFF14532D);

  static const Color tealBorder = Color(0xFFB7E2F5);
  static const Color borderCool = Color(0xFFD6E8F5);

  static const Color textTertiary = Color(0xFF55707F);
  static const Color textMutedAlt = Color(0xFF5C7488);
  static const Color purpleContainer = Color(0xFFEDE7F6);

  // Microsoft Excel export branding (kept literal so the export action reads
  // instantly as "Excel" while still living in the palette).
  static const Color excelGreen = Color(0xFF107C41);
  static const Color excelGreenTint = Color(0x1F107C41);

  static const Color scrimLight = Color(0x14000000);
  static const Color scrimFaint = Color(0x06000000);
}
