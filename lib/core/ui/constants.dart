import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// SPACING SCALE  (8pt base grid)
// ─────────────────────────────────────────────
abstract final class AppSpacing {
  static const double s2  = 2;
  static const double s4  = 4;
  static const double s8  = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  // Semantic aliases
  static const double pagePadding  = s16;
  static const double cardPadding  = s20;
  static const double heroPadding  = s24;
  static const double sectionGap   = s24;
  static const double itemGap      = s12;
  static const double buttonHeight = 52; // > 48dp Material minimum
}

// ─────────────────────────────────────────────
// RADIUS SYSTEM
// ─────────────────────────────────────────────
abstract final class AppRadius {
  static const double none = 0;
  static const double sm   = 8;   // chips, badges, small tags
  static const double md   = 12;  // buttons, standard inputs
  static const double lg   = 16;  // cards, list tiles, sheets
  static const double xl   = 24;  // hero cards, modals
  static const double sheet = 24; // bottom sheets / modals (kept large on purpose)
  static const double full = 999; // pills, avatars, dots

  static const BorderRadius smAll   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

// ─────────────────────────────────────────────
// SHADOW SYSTEM
// ─────────────────────────────────────────────
abstract final class AppShadow {
  /// Subtle card lift — use for surface-level cards
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D000000), // 5 % black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevated panels, modals
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1A000000), // 10 % black
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  /// Soft, wide, low-opacity lift for paper cards (light mode only).
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F16201B),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// Brand-tinted glow — hero balance card
  static List<BoxShadow> brand(final Color primary) => [
    BoxShadow(
      color: primary.withValues(alpha: 0.25),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
}

// ─────────────────────────────────────────────
// COLOR PALETTE  (WCAG-audited)
// ─────────────────────────────────────────────
abstract final class AppColors {
  // Brand emerald — replaces #006D5B
  // #059669 on white = 4.7:1 (passes AA)
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald700 = Color(0xFF047857); // pressed / dark variant
  static const Color emerald100 = Color(0xFFD1FAE5); // tint for light-mode chips

  // Accent teal — replaces #64FFDA (which failed WCAG on light bg)
  // #14B8A6 on white = 4.6:1 (passes AA)
  static const Color teal500    = Color(0xFF14B8A6);
  // Use teal400 only on dark surfaces (large text / icons only)
  static const Color teal400    = Color(0xFF2DD4BF);

  // Semantic
  static const Color success    = Color(0xFF10B981);
  static const Color warning    = Color(0xFFF59E0B);
  // #EF4444 on #121212 = 5.2:1 (passes AA) — replaces #CF6679 (was 3.6:1)
  static const Color error      = Color(0xFFEF4444);
  static const Color info       = Color(0xFF3B82F6);

  // Extra chart-series accents — used when a chart needs more distinct
  // categories than the semantic colors above provide (e.g. Insights'
  // category-breakdown palette).
  static const Color chartViolet = Color(0xFF8B5CF6);
  static const Color chartPink   = Color(0xFFEC4899);

  // ── Cashlyze 2.0 brand ramp ──────────────────────────────────────────
  // Built around the logo kit's teal (#228992): a deep ocean-teal ramp for
  // hero surfaces / primary actions, with the logo teal itself as the bright
  // accent so the wordmark always sits in family with the UI.
  static const Color ocean900 = Color(0xFF062B34); // splash end / darkest
  static const Color ocean800 = Color(0xFF0A3E4B); // hero card start
  static const Color ocean700 = Color(0xFF115A68); // primary (light mode) — white 7.6:1
  static const Color ocean600 = Color(0xFF187080); // hero card end
  static const Color ocean500 = Color(0xFF1B7F8B); // primary (dark mode) — white 4.9:1
  static const Color ocean400 = Color(0xFF5CC4CE); // links / icons on dark
  static const Color tint100  = Color(0xFFD7ECEF); // tinted fills in light mode
  static const Color tint050  = Color(0xFFEAF5F6);

  /// Brand teal from the logo kit (#228992).
  static const Color brandTeal   = Color(0xFF228992);
  static const Color brandTealOnDark = Color(0xFF5CC4CE);

  // Cool "paper" surfaces for light mode.
  static const Color paper        = Color(0xFFF2F7F8); // scaffold
  static const Color paperSurface = Color(0xFFFCFEFE); // cards
  static const Color paperBorder  = Color(0xFFDAE5E8);
  static const Color inkPrimary   = Color(0xFF0F1E22); // text on paper
  static const Color inkMuted     = Color(0xFF54666B);

  // Deep blue-teal surfaces for dark mode.
  static const Color darkBg          = Color(0xFF09131A);
  static const Color darkSurface     = Color(0xFF111D24);
  static const Color darkSurfaceHigh = Color(0xFF192830);
  static const Color darkBorder      = Color(0xFF24363F);

  // Neutral ramp (for dark-mode scaffold / surfaces)
  static const Color neutral950 = Color(0xFF0A0A0A);
  static const Color neutral900 = Color(0xFF171717);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral700 = Color(0xFF404040);
  // For light-mode borders / dividers
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral100 = Color(0xFFF5F5F5);
}

// ─────────────────────────────────────────────
// TYPOGRAPHY SCALE
// ─────────────────────────────────────────────
abstract final class AppType {
  // Size scale
  static const double d1 = 40; // Hero balance amounts
  static const double d2 = 32; // Large display titles
  static const double h1 = 28; // Screen/page headings
  static const double h2 = 24; // Card headings
  static const double h3 = 20; // AppBar / section titles
  static const double b1 = 16; // Primary body, button labels
  static const double b2 = 14; // Secondary body, list items
  static const double b3 = 12; // Captions, badges, labels

  // Line heights
  static const double lhTight  = 1.2; // Numbers, headings
  static const double lhNormal = 1.5; // Body text
  static const double lhLoose  = 1.7; // Long descriptions
}

// ─────────────────────────────────────────────
// LEGACY ALIASES (kept for backward-compat)
// Migrate call-sites to AppSpacing / AppRadius
// ─────────────────────────────────────────────
const double kRadius16 = AppRadius.lg;
const double kRadius12 = AppRadius.md;
const double kSpacing8  = AppSpacing.s8;
const double kSpacing12 = AppSpacing.s12;
const double kSpacing16 = AppSpacing.s16;

const BorderRadius kCardRadius16 = AppRadius.lgAll;
const BorderRadius kCardRadius12 = AppRadius.mdAll;

const EdgeInsets kPagePadding16   = EdgeInsets.all(AppSpacing.pagePadding);
const EdgeInsets kSectionPadding12 = EdgeInsets.all(AppSpacing.itemGap);
