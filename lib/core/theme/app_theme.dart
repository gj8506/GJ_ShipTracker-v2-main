import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Application-wide theme built on a 75 / 20 / 5 color balance:
///   75% faint-white azure background, 20% logo-blue interface,
///   5% deep ink text + azure accent.
///
/// Widget-level styling lives here so Admin/Staff screens and the Customer
/// Portal stay visually consistent without changing any business logic.
class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.navyPrimary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.tealContainer,
      onPrimaryContainer: AppColors.tealDark,
      secondary: AppColors.tealAccent,
      onSecondary: AppColors.textOnPrimary,
      secondaryContainer: AppColors.tealContainer,
      onSecondaryContainer: AppColors.tealDark,
      tertiary: AppColors.navyMuted,
      onTertiary: AppColors.textOnPrimary,
      error: AppColors.errorRed,
      onError: AppColors.textOnPrimary,
      surface: AppColors.surfaceWhite,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.borderSubtle,
      shadow: Color(0x1A0A4763),
      scrim: Color(0x800A4763),
      inverseSurface: AppColors.navyPrimary,
      onInverseSurface: AppColors.textOnDark,
      inversePrimary: AppColors.tealSecondary,
    );

    final baseTextTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: AppColors.textPrimary,
        height: 1.45,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        height: 1.35,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      canvasColor: AppColors.backgroundLight,
      dividerColor: AppColors.borderSubtle,
      splashColor: AppColors.tealAccent.withValues(alpha: 0.08),
      highlightColor: AppColors.navyPrimary.withValues(alpha: 0.04),
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.chromeBlue,
        foregroundColor: AppColors.navyDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.borderStrong,
        centerTitle: false,
        titleSpacing: 16,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.navyDark,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.navyDark,
          size: 22,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.navyDark,
          size: 22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.chromeBlue,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.navyPrimary.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: selected ? AppColors.navyDark : AppColors.navyMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? AppColors.navyDark : AppColors.navyMuted,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.chromeBlue,
        selectedItemColor: AppColors.navyDark,
        unselectedItemColor: AppColors.navyMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
          side: BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyPrimary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textOnPrimary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navyPrimary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyPrimary,
          backgroundColor: AppColors.surfaceWhite,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: AppColors.borderLight),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navyPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.navyPrimary,
          highlightColor: AppColors.tealAccent.withValues(alpha: 0.08),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.navyPrimary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 1,
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.tealDark,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.navyMuted,
        suffixIconColor: AppColors.navyMuted,
        errorStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.errorRed,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tealAccent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceWhite,
        selectedColor: AppColors.navyPrimary,
        disabledColor: AppColors.surfaceMuted,
        checkmarkColor: AppColors.textOnPrimary,
        showCheckmark: false,
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.navyPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.textOnPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceWhite,
        modalBackgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navyPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.tealSecondary,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.navyMuted,
        textColor: AppColors.textPrimary,
        titleTextStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 22,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.tealAccent,
        linearTrackColor: AppColors.surfaceMuted,
        circularTrackColor: AppColors.surfaceMuted,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.navyPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.textOnPrimary),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.tealAccent;
          }
          return AppColors.borderStrong;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surfaceWhite;
          }
          return AppColors.surfaceWhite;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.navyPrimary;
          }
          return AppColors.surfaceVariant;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(
          AppColors.borderLight,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(
            AppColors.surfaceWhite,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.tealAccent,
        selectionColor: AppColors.tealAccent.withValues(alpha: 0.20),
        selectionHandleColor: AppColors.tealAccent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          AppColors.navyLight.withValues(alpha: 0.55),
        ),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(5),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.navyPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.textOnPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.navyMuted,
        size: 22,
      ),
    );
  }
}
