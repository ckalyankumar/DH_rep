import 'package:flutter/material.dart';

/// Responsive breakpoints: phone <600, tablet 600–899, desktop ≥900.
class Responsive {
  static bool isPhone(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < 600;

  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600 &&
      MediaQuery.of(ctx).size.width < 900;

  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 900;

  static int gridColumns(BuildContext ctx) {
    if (isDesktop(ctx)) return 3;
    if (isTablet(ctx)) return 2;
    return 1;
  }
}
