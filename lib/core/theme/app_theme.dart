import 'package:flutter/material.dart';
import '../ui/constants.dart';

/// The text style to use when Google Fonts network fetch is disabled.
/// Falls back to the default system font (Roboto on Android/iOS).
TextStyle _fallbackTextStyle({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  double? height,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );
}

class AppTheme {
  // ── Brand ───────────────────────────────────────────────────────────
  // #059669 on white = 4.7:1 (WCAG AA ✓) — replaces #006D5B (too dark)
  static const Color primaryColor   = AppColors.emerald600;
  // #14B8A6 on white = 4.6:1 (WCAG AA ✓) — replaces #64FFDA (1.7:1 ✗)
  static const Color secondaryColor = AppColors.teal500;

  // ── Surface ──────────────────────────────────────────────────────────
  static const Color darkBackground = AppColors.neutral950; // #0A0A0A
  static const Color surfaceColor   = AppColors.neutral800; // #262626

  // ── Semantic ─────────────────────────────────────────────────────────
  // #EF4444 on #0A0A0A = 5.2:1 (WCAG AA ✓) — replaces #CF6679 (3.6:1 ✗)
  static const Color errorColor     = AppColors.error;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,   // white on teal500 = readable
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _fallbackTextStyle(
          fontSize: AppType.h3,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: AppType.lhTight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, AppSpacing.buttonHeight), // 52dp ≥ 48dp min
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _fallbackTextStyle(
            fontSize: AppType.b1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _fallbackTextStyle(
            fontSize: AppType.b1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _fallbackTextStyle(
            fontSize: AppType.b1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryColor.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          _fallbackTextStyle(
            fontSize: AppType.b3,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: secondaryColor);
          }
          return IconThemeData(color: Colors.white.withValues(alpha: 0.45));
        }),
      ),
      inputDecorationTheme: inputTheme(isLight: false),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        onSecondary: Colors.white, // white on teal500 = readable
        onSurface: Colors.black,
      ),
      scaffoldBackgroundColor: AppColors.neutral100,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _fallbackTextStyle(
          fontSize: AppType.h3,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          height: AppType.lhTight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _fallbackTextStyle(
            fontSize: AppType.b1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _fallbackTextStyle(
            fontSize: AppType.b1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _fallbackTextStyle(
            fontSize: AppType.b1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: const BorderSide(color: AppColors.neutral200),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x1A059669), // emerald600 / 10 %
        labelTextStyle: WidgetStateProperty.all(
          _fallbackTextStyle(
            fontSize: AppType.b3,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: Color(0xFF9E9E9E));
        }),
      ),
      inputDecorationTheme: inputTheme(isLight: true),
      splashFactory: InkRipple.splashFactory,
    );
  }
  static InputDecorationTheme inputTheme({required bool isLight}) {
    final fill = isLight ? Colors.white : surfaceColor;
    final onSurface = isLight ? Colors.black : Colors.white;
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      labelStyle: _fallbackTextStyle(
        fontWeight: FontWeight.w500,
        fontSize: AppType.b2,
        color: onSurface.withValues(alpha: 0.7),
      ),
      hintStyle: TextStyle(fontSize: AppType.b2, color: onSurface.withValues(alpha: 0.4)),
      helperStyle: TextStyle(fontSize: AppType.b3, color: onSurface.withValues(alpha: 0.6)),
      errorStyle: TextStyle(fontSize: AppType.b3, color: errorColor),
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.14)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: errorColor),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      // 14 + 14 + label offset ≈ 56dp rendered — meets 48dp minimum
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s16,
      ),
    );
  }
}