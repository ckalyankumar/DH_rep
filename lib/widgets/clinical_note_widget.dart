import 'package:flutter/material.dart';

enum ClinicalNoteType { info, warning, redFlag }

/// Reusable clinical note for statistical insights, warnings, and red flags.
class ClinicalNoteWidget extends StatelessWidget {
  final ClinicalNoteType type;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ClinicalNoteWidget({
    super.key,
    required this.type,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  static const Color _infoBg = Color(0xFFEAF6F3);
  static const Color _infoBorder = Color(0xFF2E9B82);
  static const Color _warningBg = Color(0xFFFEF7E6);
  static const Color _warningBorder = Color(0xFFE8B84B);
  static const Color _redFlagBg = Color(0xFFFAEDED);
  static const Color _redFlagBorder = Color(0xFFB84040);

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, double borderWidth, Widget leading) =
        _styling();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: border.withValues(alpha: type == ClinicalNoteType.redFlag ? 0.5 : 0.25),
          width: borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, double, Widget) _styling() {
    switch (type) {
      case ClinicalNoteType.info:
        return (
          _infoBg,
          _infoBorder,
          1.0,
          Icon(Icons.bar_chart_rounded, color: _infoBorder, size: 24),
        );
      case ClinicalNoteType.warning:
        return (
          _warningBg,
          _warningBorder,
          1.0,
          Icon(Icons.info_outline, color: _warningBorder, size: 24),
        );
      case ClinicalNoteType.redFlag:
        return (
          _redFlagBg,
          _redFlagBorder,
          1.5,
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: _redFlagBorder,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              '!!!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
    }
  }
}

/// Shows a modal with guidance on when to seek medical care.
void showWhenToSeeDoctorModal(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('When to See a Dermatologist'),
      content: SingleChildScrollView(
        child: Text(
          'Seek prompt medical care if you experience:\n\n'
          '• Widespread or rapidly spreading rash\n'
          '• Signs of infection (pus, fever, red streaks)\n'
          '• Joint pain with skin symptoms (possible psoriatic arthritis)\n'
          '• Erythroderma (redness covering most of the body)\n'
          '• Pustular or inverse psoriasis\n'
          '• Symptoms that don\'t improve with self-care\n\n'
          'This app does not diagnose. Always discuss concerning symptoms '
          'with your healthcare provider.',
          style: const TextStyle(height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
