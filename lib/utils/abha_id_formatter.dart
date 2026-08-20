import 'package:flutter/services.dart';

/// Formats ABHA ID as XX-XXXX-XXXX-XXXX while the user types.
class AbhaIdFormatter extends TextInputFormatter {
  const AbhaIdFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 14 ? digits.substring(0, 14) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 2 || i == 6 || i == 10) buffer.write('-');
      buffer.write(capped[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

