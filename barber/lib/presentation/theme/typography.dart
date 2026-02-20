import 'package:flutter/material.dart';

/// Typography styles for Barber Club using Orbitron (applied via Theme).
/// Use Theme.of(context).textTheme + copyWith for consistent styling.
class AppTypography {
  AppTypography._();

  static const display = TextStyle(
    fontWeight: FontWeight.w700,
    letterSpacing: 3,
  );

  static const sectionTitle = TextStyle(
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
  );

  static const body = TextStyle(
    fontWeight: FontWeight.w400,
  );
}
