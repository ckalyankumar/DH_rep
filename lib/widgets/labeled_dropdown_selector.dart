import 'package:flutter/material.dart';

/// Reusable labeled dropdown selector (e.g. condition, mood, category).
/// Wrap in a card-style container with optional custom decoration.
class LabeledDropdownSelector extends StatelessWidget {
  /// Label shown above the dropdown (e.g. "Select Your Condition").
  final String label;

  /// Currently selected value (must match one of [items] values).
  final String value;

  /// Menu items for the dropdown.
  final List<DropdownMenuItem<String>> items;

  /// Called when the selection changes. [value] may be null if dismissed.
  final ValueChanged<String?> onChanged;

  /// Optional key for the dropdown (useful for tests).
  final Key? dropdownKey;

  /// Optional container decoration. If null, uses default card-style.
  final BoxDecoration? decoration;

  /// Optional padding around the content. Defaults to 16.
  final EdgeInsetsGeometry? padding;

  const LabeledDropdownSelector({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.dropdownKey,
    this.decoration,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: decoration ??
          BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2c3e50),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: dropdownKey,
            initialValue: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFdee2e6)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
