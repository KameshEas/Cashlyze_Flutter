import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/constants.dart';

// When running widget tests the TestWidgets binding prevents network
// requests; google_fonts may attempt to fetch fonts and fail. Tests can
// call `disableGoogleFontsForTests()` to force using fallback text styles
// that do not perform network fetches.
bool _disableGoogleFontsForTests = false;

/// Call from tests to avoid google_fonts performing network fetches.
void disableGoogleFontsForTests() => _disableGoogleFontsForTests = true;

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
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: !_disableGoogleFontsForTests
          ? GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            )
          : ThemeData.dark()
              .textTheme
              .apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: !_disableGoogleFontsForTests
            ? GoogleFonts.inter(
                fontSize: AppType.h3, // 20 from scale — no more magic number
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: AppType.lhTight,
              )
            : TextStyle(
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
          textStyle: !_disableGoogleFontsForTests
              ? GoogleFonts.inter(
                  fontSize: AppType.b1,
                  fontWeight: FontWeight.w600,
                )
              : TextStyle(fontSize: AppType.b1, fontWeight: FontWeight.w600),
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
          textStyle: !_disableGoogleFontsForTests
              ? GoogleFonts.inter(
                  fontSize: AppType.b1,
                  fontWeight: FontWeight.w600,
                )
              : TextStyle(fontSize: AppType.b1, fontWeight: FontWeight.w600),
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
          textStyle: !_disableGoogleFontsForTests
              ? GoogleFonts.inter(
                  fontSize: AppType.b1,
                  fontWeight: FontWeight.w600,
                )
              : TextStyle(fontSize: AppType.b1, fontWeight: FontWeight.w600),
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
          !_disableGoogleFontsForTests
              ? GoogleFonts.inter(
                  fontSize: AppType.b3,
                  fontWeight: FontWeight.w500,
                )
              : TextStyle(fontSize: AppType.b3, fontWeight: FontWeight.w500),
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
        surface: Colors.white,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white, // white on teal500 = readable
        onSurface: Colors.black,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.neutral100,
      textTheme: !_disableGoogleFontsForTests
          ? GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            )
          : ThemeData.light()
              .textTheme
              .apply(bodyColor: Colors.black, displayColor: Colors.black),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: !_disableGoogleFontsForTests
            ? GoogleFonts.inter(
                fontSize: AppType.h3,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                height: AppType.lhTight,
              )
            : TextStyle(
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
          textStyle: !_disableGoogleFontsForTests
              ? GoogleFonts.inter(
                  fontSize: AppType.b1,
                  fontWeight: FontWeight.w600,
                )
              : TextStyle(fontSize: AppType.b1, fontWeight: FontWeight.w600),
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
          textStyle: !_disableGoogleFontsForTests
              ? GoogleFonts.inter(
                  fontSize: AppType.b1,
                  fontWeight: FontWeight.w600,
                )
              : TextStyle(fontSize: AppType.b1, fontWeight: FontWeight.w600),
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
          textStyle: !_disableGoogleFontsForTests
              ? GoogleFonts.inter(
                  fontSize: AppType.b1,
                  fontWeight: FontWeight.w600,
                )
              : TextStyle(fontSize: AppType.b1, fontWeight: FontWeight.w600),
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
          !_disableGoogleFontsForTests
              ? GoogleFonts.inter(
                  fontSize: AppType.b3,
                  fontWeight: FontWeight.w500,
                )
              : TextStyle(fontSize: AppType.b3, fontWeight: FontWeight.w500),
        ),
        // FIX: was WidgetStatePropertyAll (no selected distinction = no feedback)
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
      labelStyle: !_disableGoogleFontsForTests
          ? GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: AppType.b2,
              color: onSurface.withValues(alpha: 0.7),
            )
          : TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: AppType.b2,
              color: onSurface.withValues(alpha: 0.7),
            ),
      hintStyle: !_disableGoogleFontsForTests
          ? GoogleFonts.inter(
              fontSize: AppType.b2,
              color: onSurface.withValues(alpha: 0.4),
            )
          : TextStyle(fontSize: AppType.b2, color: onSurface.withValues(alpha: 0.4)),
      helperStyle: !_disableGoogleFontsForTests
          ? GoogleFonts.inter(
              fontSize: AppType.b3,
              color: onSurface.withValues(alpha: 0.6),
            )
          : TextStyle(fontSize: AppType.b3, color: onSurface.withValues(alpha: 0.6)),
      errorStyle: !_disableGoogleFontsForTests
          ? GoogleFonts.inter(
              fontSize: AppType.b3,
              color: errorColor,
            )
          : TextStyle(fontSize: AppType.b3, color: errorColor),
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
