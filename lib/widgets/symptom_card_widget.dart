import 'package:flutter/material.dart';

class SymptomCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;
  final Color? borderColor;
  final EdgeInsets padding;

  const SymptomCardWidget({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFFf8f9fa),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: borderColor ?? const Color(0xFF3498db),
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2c3e50),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6c757d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
