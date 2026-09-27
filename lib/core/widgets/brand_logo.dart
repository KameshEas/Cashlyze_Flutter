import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The "Cashlyze" wordmark lockup, switching between the brand kit's
/// teal-on-transparent and white-on-transparent variants so it stays
/// legible on both light and dark surfaces.
///
/// Kept as SVG (rather than a rasterized PNG) so a future splash animation
/// can drive it with [SvgPicture]'s pull-based rendering — e.g. clipping or
/// fading in the wordmark's paths — without shipping multiple bitmap sizes.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 72});

  final double height;

  @override
  Widget build(final BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      isDark
          ? 'assets/branding/cashlyze_logo_white.svg'
          : 'assets/branding/cashlyze_logo_primary.svg',
      height: height,
    );
  }
}
