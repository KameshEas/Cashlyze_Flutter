import 'package:flutter/material.dart';

import 'constants.dart';

/// Icon + accent colour for a spending/income category, so every list row
/// gets its own recognisable tile (Collage 2's coloured category chips)
/// instead of one generic glyph.
///
/// Matching is by keyword on the category *name* (categories are
/// user-defined, so there is no fixed id set); unknown names get a stable
/// colour derived from the name, so "Pets" is always the same hue.
@immutable
class CategoryStyle {
  const CategoryStyle(this.icon, this.color);

  final IconData icon;
  final Color color;

  /// Tinted background that stays legible with [color] as the foreground.
  Color tint(final Brightness b) => color.withValues(alpha: b == Brightness.dark ? 0.22 : 0.14);
}

const _fallbackColors = <Color>[
  Color(0xFF6C5CE7), // violet
  Color(0xFFD6336C), // rose
  Color(0xFF2B8A3E), // green
  Color(0xFFE8590C), // orange
  Color(0xFF1C7ED6), // blue
  Color(0xFF0C8599), // cyan
];

const _rules = <(List<String>, IconData, Color)>[
  (['food', 'dining', 'restaurant', 'zomato', 'swiggy', 'coffee', 'grocer', 'snack'], Icons.restaurant_rounded, Color(0xFFE8590C)),
  (['transport', 'uber', 'ola', 'fuel', 'petrol', 'taxi', 'metro', 'travel', 'bus'], Icons.directions_car_rounded, Color(0xFFD6336C)),
  (['shop', 'amazon', 'cloth', 'flipkart', 'mall'], Icons.shopping_bag_rounded, Color(0xFF6C5CE7)),
  (['util', 'bill', 'electric', 'water', 'internet', 'recharge', 'rent'], Icons.bolt_rounded, Color(0xFF1C7ED6)),
  (['health', 'medic', 'pharma', 'doctor', 'hospital'], Icons.favorite_rounded, Color(0xFFE03131)),
  (['entertain', 'movie', 'netflix', 'game', 'music'], Icons.movie_rounded, Color(0xFFAE3EC9)),
  (['salary', 'income', 'freelance', 'bonus', 'refund'], Icons.account_balance_wallet_rounded, Color(0xFF2B8A3E)),
  (['educat', 'course', 'school', 'book'], Icons.school_rounded, Color(0xFF0C8599)),
  (['emi', 'loan', 'insurance'], Icons.credit_score_rounded, Color(0xFFF08C00)),
];

CategoryStyle categoryStyleFor(final String? name, {final bool isIncome = false}) {
  final n = (name ?? '').trim().toLowerCase();
  if (n.isNotEmpty) {
    for (final (keys, icon, color) in _rules) {
      if (keys.any(n.contains)) return CategoryStyle(icon, color);
    }
    final hue = _fallbackColors[n.codeUnits.fold<int>(0, (final a, final c) => a + c) % _fallbackColors.length];
    return CategoryStyle(Icons.sell_rounded, hue);
  }
  return isIncome
      ? const CategoryStyle(Icons.south_west_rounded, Color(0xFF2B8A3E))
      : const CategoryStyle(Icons.category_rounded, Color(0xFF1C7ED6));
}

/// Category glyph for lists: a rounded tile tinted with the category's own
/// colour and a matching icon, so rows are quick to tell apart at a glance.
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({super.key, required this.style, this.size = 44});

  final CategoryStyle style;
  final double size;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.tint(theme.brightness),
        borderRadius: AppRadius.mdAll,
      ),
      child: Icon(style.icon, size: size * 0.5, color: style.color),
    );
  }
}
