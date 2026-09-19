import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dhealth/utils/theme.dart';

/// The Siequi wordmark: "Siequi" set in Fraunces 500. The brand identity is
/// wordmark-only (no symbol); use this instead of hand-styling the text.
class SiequiWordmark extends StatelessWidget {
  const SiequiWordmark({
    super.key,
    this.fontSize = 56,
    this.color = AppTheme.primaryDark,
  });

  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Siequi',
      style: GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.1,
      ),
    );
  }
}
