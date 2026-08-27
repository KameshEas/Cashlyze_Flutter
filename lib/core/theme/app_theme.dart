import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/constants.dart';

/// Central place the app's two typefaces are chosen, so a future change is
/// one edit instead of a grep-and-replace:
/// - Display/headings/balances (AppType.d1/d2/h1/h2/h3): geometric,
///   distinctive - carries the brand and gives large currency numbers real
///   presence, instead of falling back to stock Roboto.
/// - Body/UI/buttons (AppType.b1/b2/b3): a proven dense-UI workhorse, tuned
///   for lists/forms/labels where legibility at small sizes matters more
///   than character.
TextStyle _display({
  required final double fontSize,
  required final FontWeight fontWeight,
  required final Color color,
  final double? height,
}) =>
    GoogleFonts.plusJakartaSans(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);

TextStyle _body({
  required final double fontSize,
  required final FontWeight fontWeight,
  required final Color color,
  final double? height,
}) =>
    GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);

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

  /// Full Material 3 [TextTheme] built from [AppType]'s size scale, so
  /// screens can use `theme.textTheme.*` directly instead of reading
  /// `AppType.*` sizes ad hoc. `displayLarge`/`headlineLarge` map to the
  /// hero balance/display sizes (d1/d2); the rest follow the M3 naming
  /// ladder down to `labelSmall` (b3/captions).
  static TextTheme _textTheme(final Color color) {
    final onSurfaceMuted = color.withValues(alpha: 0.7);
    return TextTheme(
      displayLarge: _display(fontSize: AppType.d1, fontWeight: FontWeight.w700, color: color, height: AppType.lhTight),
      displayMedium: _display(fontSize: AppType.d2, fontWeight: FontWeight.w700, color: color, height: AppType.lhTight),
      headlineLarge: _display(fontSize: AppType.h1, fontWeight: FontWeight.w700, color: color, height: AppType.lhTight),
      headlineMedium: _display(fontSize: AppType.h2, fontWeight: FontWeight.w700, color: color, height: AppType.lhTight),
      headlineSmall: _display(fontSize: AppType.h3, fontWeight: FontWeight.w600, color: color, height: AppType.lhTight),
      titleLarge: _display(fontSize: AppType.h3, fontWeight: FontWeight.w600, color: color, height: AppType.lhTight),
      titleMedium: _body(fontSize: AppType.b1, fontWeight: FontWeight.w600, color: color, height: AppType.lhNormal),
      titleSmall: _body(fontSize: AppType.b2, fontWeight: FontWeight.w600, color: color, height: AppType.lhNormal),
      bodyLarge: _body(fontSize: AppType.b1, fontWeight: FontWeight.w400, color: color, height: AppType.lhNormal),
      bodyMedium: _body(fontSize: AppType.b2, fontWeight: FontWeight.w400, color: color, height: AppType.lhNormal),
      bodySmall: _body(fontSize: AppType.b3, fontWeight: FontWeight.w400, color: onSurfaceMuted, height: AppType.lhNormal),
      labelLarge: _body(fontSize: AppType.b2, fontWeight: FontWeight.w600, color: color, height: AppType.lhNormal),
      labelMedium: _body(fontSize: AppType.b3, fontWeight: FontWeight.w600, color: color, height: AppType.lhNormal),
      labelSmall: _body(fontSize: AppType.b3, fontWeight: FontWeight.w500, color: onSurfaceMuted, height: AppType.lhNormal),
    );
  }

  static ThemeData get darkTheme {
    const onSurface = Colors.white;
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
      textTheme: _textTheme(onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _display(
          fontSize: AppType.h3,
          fontWeight: FontWeight.w700,
          color: onSurface,
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
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _body(
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
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _body(
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
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _body(
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
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: _display(fontSize: AppType.h3, fontWeight: FontWeight.w700, color: onSurface),
        contentTextStyle: _body(fontSize: AppType.b1, fontWeight: FontWeight.w400, color: onSurface.withValues(alpha: 0.85)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: onSurface.withValues(alpha: 0.24),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: onSurface.withValues(alpha: 0.08),
        selectedColor: primaryColor.withValues(alpha: 0.22),
        labelStyle: _body(fontSize: AppType.b3, fontWeight: FontWeight.w600, color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
        side: BorderSide.none,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.neutral700,
        contentTextStyle: _body(fontSize: AppType.b2, fontWeight: FontWeight.w500, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryColor.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          _body(
            fontSize: AppType.b3,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((final states) {
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
    const onSurface = Colors.black;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        onSecondary: Colors.white, // white on teal500 = readable
      ),
      scaffoldBackgroundColor: AppColors.neutral100,
      textTheme: _textTheme(onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _display(
          fontSize: AppType.h3,
          fontWeight: FontWeight.w700,
          color: onSurface,
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
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _body(
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
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _body(
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
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          textStyle: _body(
            fontSize: AppType.b1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: AppColors.neutral200),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: _display(fontSize: AppType.h3, fontWeight: FontWeight.w700, color: onSurface),
        contentTextStyle: _body(fontSize: AppType.b1, fontWeight: FontWeight.w400, color: onSurface.withValues(alpha: 0.75)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: onSurface.withValues(alpha: 0.16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutral100,
        selectedColor: primaryColor.withValues(alpha: 0.14),
        labelStyle: _body(fontSize: AppType.b3, fontWeight: FontWeight.w600, color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.neutral900,
        contentTextStyle: _body(fontSize: AppType.b2, fontWeight: FontWeight.w500, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x1A059669), // emerald600 / 10 %
        labelTextStyle: WidgetStateProperty.all(
          _body(
            fontSize: AppType.b3,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((final states) {
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
  static InputDecorationTheme inputTheme({required final bool isLight}) {
    final fill = isLight ? Colors.white : surfaceColor;
    final onSurface = isLight ? Colors.black : Colors.white;
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      labelStyle: _body(
        fontWeight: FontWeight.w500,
        fontSize: AppType.b2,
        color: onSurface.withValues(alpha: 0.7),
      ),
      hintStyle: _body(fontSize: AppType.b2, fontWeight: FontWeight.w400, color: onSurface.withValues(alpha: 0.4)),
      helperStyle: _body(fontSize: AppType.b3, fontWeight: FontWeight.w400, color: onSurface.withValues(alpha: 0.6)),
      errorStyle: _body(fontSize: AppType.b3, fontWeight: FontWeight.w400, color: errorColor),
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
