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

/// Cashlyze 2.0 theme: cool paper + deep ocean teal (from the logo) in light mode,
/// deep blue-teal surfaces in dark mode. Both modes are built from one
/// [_build] so they can't drift apart.
class AppTheme {
  // ── Brand ───────────────────────────────────────────────────────────
  // Ocean700 on paper = 7.4:1 (AAA); white on ocean700 = 7.6:1.
  static const Color primaryColor   = AppColors.ocean700;
  // Logo-kit teal. White on #228992 = 4.5:1 (AA for large/bold labels).
  static const Color secondaryColor = AppColors.brandTeal;

  // ── Surface ──────────────────────────────────────────────────────────
  static const Color darkBackground = AppColors.darkBg;
  static const Color surfaceColor   = AppColors.darkSurface;

  // ── Semantic ─────────────────────────────────────────────────────────
  static const Color errorColor     = AppColors.error;

  /// Full Material 3 [TextTheme] built from [AppType]'s size scale, so
  /// screens can use `theme.textTheme.*` directly instead of reading
  /// `AppType.*` sizes ad hoc. `displayLarge`/`headlineLarge` map to the
  /// hero balance/display sizes (d1/d2); the rest follow the M3 naming
  /// ladder down to `labelSmall` (b3/captions).
  static TextTheme _textTheme(final Color color, final Color muted) {
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
      bodySmall: _body(fontSize: AppType.b3, fontWeight: FontWeight.w400, color: muted, height: AppType.lhNormal),
      labelLarge: _body(fontSize: AppType.b2, fontWeight: FontWeight.w600, color: color, height: AppType.lhNormal),
      labelMedium: _body(fontSize: AppType.b3, fontWeight: FontWeight.w600, color: color, height: AppType.lhNormal),
      labelSmall: _body(fontSize: AppType.b3, fontWeight: FontWeight.w500, color: muted, height: AppType.lhNormal),
    );
  }

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        primary: AppColors.ocean500,
        secondary: AppColors.brandTealOnDark,
        scaffold: AppColors.darkBg,
        surface: AppColors.darkSurface,
        surfaceHigh: AppColors.darkSurfaceHigh,
        border: AppColors.darkBorder,
        onSurface: const Color(0xFFEAF0EC),
        muted: const Color(0xFFEAF0EC).withValues(alpha: 0.64),
        navIndicator: AppColors.ocean500.withValues(alpha: 0.22),
        navSelected: AppColors.ocean400,
        navIdle: const Color(0xFFEAF0EC).withValues(alpha: 0.5),
        snackBg: AppColors.darkSurfaceHigh,
      );

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        primary: AppColors.ocean700,
        secondary: AppColors.brandTeal,
        scaffold: AppColors.paper,
        surface: AppColors.paperSurface,
        surfaceHigh: AppColors.tint050,
        border: AppColors.paperBorder,
        onSurface: AppColors.inkPrimary,
        muted: AppColors.inkMuted,
        navIndicator: AppColors.tint100,
        navSelected: AppColors.ocean700,
        navIdle: AppColors.inkMuted.withValues(alpha: 0.75),
        snackBg: AppColors.inkPrimary,
      );

  static ThemeData _build({
    required final Brightness brightness,
    required final Color primary,
    required final Color secondary,
    required final Color scaffold,
    required final Color surface,
    required final Color surfaceHigh,
    required final Color border,
    required final Color onSurface,
    required final Color muted,
    required final Color navIndicator,
    required final Color navSelected,
    required final Color navIdle,
    required final Color snackBg,
  }) {
    final isLight = brightness == Brightness.light;
    final scheme = (isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceHigh,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceHigh,
      // Explicit containers: Material's defaults are lavender and would
      // leak a purple tint wherever a screen reads them.
      primaryContainer: isLight ? AppColors.tint100 : AppColors.ocean800,
      onPrimaryContainer: isLight ? AppColors.ocean800 : AppColors.tint100,
      secondaryContainer: isLight ? AppColors.tint050 : AppColors.darkSurfaceHigh,
      onSecondaryContainer: isLight ? AppColors.ocean800 : AppColors.tint100,
      tertiaryContainer: isLight ? const Color(0xFFFFF1D6) : const Color(0xFF3A2D12),
      onTertiaryContainer: isLight ? const Color(0xFF5C3B00) : const Color(0xFFFFE2A8),
      errorContainer: isLight ? const Color(0xFFFDE4E4) : const Color(0xFF431818),
      onErrorContainer: isLight ? const Color(0xFF7A1212) : const Color(0xFFFFD6D6),
      outline: border,
      outlineVariant: border,
      error: errorColor,
      onError: Colors.white,
      surfaceTint: Colors.transparent,
    );

    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.lgAll);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s12);
    final buttonText = _body(fontSize: AppType.b1, fontWeight: FontWeight.w600, color: Colors.white);
    const buttonSize = Size(64, AppSpacing.buttonHeight); // 52dp ≥ 48dp min

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      dividerColor: border,
      textTheme: _textTheme(onSurface, muted),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isLight ? primary : AppColors.ocean400,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: isLight ? primary : AppColors.ocean400, width: 1.4),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isLight ? primary : AppColors.ocean400,
          textStyle: _body(fontSize: AppType.b2, fontWeight: FontWeight.w600, color: primary),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (final s) => s.contains(WidgetState.selected) ? primary : onSurface.withValues(alpha: 0.22),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
        fillColor: WidgetStateProperty.resolveWith(
          (final s) => s.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
        side: BorderSide(color: onSurface.withValues(alpha: 0.4), width: 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isLight ? primary : AppColors.ocean400,
        linearTrackColor: onSurface.withValues(alpha: 0.08),
        linearMinHeight: 8,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: _display(fontSize: AppType.h3, fontWeight: FontWeight.w700, color: onSurface),
        contentTextStyle: _body(fontSize: AppType.b1, fontWeight: FontWeight.w400, color: onSurface.withValues(alpha: 0.8)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: onSurface.withValues(alpha: 0.2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: primary,
        secondarySelectedColor: primary,
        // Selected chips are filled with the primary colour, so their label
        // must flip to white or it would be dark-on-teal.
        labelStyle: WidgetStateTextStyle.resolveWith(
          (final s) => _body(
            fontSize: AppType.b2,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? Colors.white : onSurface,
          ),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
        side: BorderSide(color: border),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: _body(fontSize: AppType.b2, fontWeight: FontWeight.w500, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: navIndicator,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((final states) {
          final selected = states.contains(WidgetState.selected);
          return _body(
            fontSize: AppType.b3 - 1,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? navSelected : navIdle,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((final states) {
          return IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? navSelected : navIdle,
          );
        }),
      ),
      inputDecorationTheme: inputTheme(isLight: isLight),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static InputDecorationTheme inputTheme({required final bool isLight}) {
    final fill = isLight ? Colors.white : AppColors.darkSurfaceHigh;
    final onSurface = isLight ? AppColors.inkPrimary : const Color(0xFFEAF0EC);
    final edge = isLight ? AppColors.paperBorder : AppColors.darkBorder;
    final focus = isLight ? AppColors.ocean700 : AppColors.ocean400;
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      prefixIconColor: onSurface.withValues(alpha: 0.6),
      suffixIconColor: onSurface.withValues(alpha: 0.6),
      labelStyle: _body(
        fontWeight: FontWeight.w500,
        fontSize: AppType.b2,
        color: onSurface.withValues(alpha: 0.7),
      ),
      hintStyle: _body(fontSize: AppType.b2, fontWeight: FontWeight.w400, color: onSurface.withValues(alpha: 0.4)),
      helperStyle: _body(fontSize: AppType.b3, fontWeight: FontWeight.w400, color: onSurface.withValues(alpha: 0.6)),
      errorStyle: _body(fontSize: AppType.b3, fontWeight: FontWeight.w400, color: errorColor),
      border: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: edge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: edge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: focus, width: 1.8),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: errorColor),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: errorColor, width: 1.8),
      ),
      // 14 + 14 + label offset ≈ 56dp rendered — meets 48dp minimum
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s16,
      ),
    );
  }
}
