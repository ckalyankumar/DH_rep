import 'package:flutter/material.dart';

/// Risk band for WCAG-compliant badges (icon + text + color, not color alone).
enum RiskBadgeType {
  low,
  medium,
  high,
  urgent,
}

/// Size variants for the risk badge.
enum RiskBadgeSize {
  sm,
  lg,
}

class RiskBadgeWidget extends StatelessWidget {
  final RiskBadgeType type;
  final String label;
  final int? score;
  final RiskBadgeSize size;
  final EdgeInsets? padding;

  const RiskBadgeWidget({
    super.key,
    required this.type,
    required this.label,
    this.score,
    this.size = RiskBadgeSize.sm,
    this.padding,
  });

  static const _lowColor = Color(0xFF2E9B82);
  static const _mediumColor = Color(0xFFE8B84B);
  static const _highColor = Color(0xFFD9724C);
  static const _urgentColor = Color(0xFFB84040);

  /// Resolve effective band: when type is high but label is 'Urgent', treat as urgent
  /// (backward compat for callers that pass type: high, label: 'Urgent').
  RiskBadgeType get _effectiveBand {
    if (type == RiskBadgeType.high && label == 'Urgent') {
      return RiskBadgeType.urgent;
    }
    return type;
  }

  Color get _bandColor {
    switch (_effectiveBand) {
      case RiskBadgeType.low:
        return _lowColor;
      case RiskBadgeType.medium:
        return _mediumColor;
      case RiskBadgeType.high:
        return _highColor;
      case RiskBadgeType.urgent:
        return _urgentColor;
    }
  }

  String get _iconText {
    switch (_effectiveBand) {
      case RiskBadgeType.low:
        return '✓';
      case RiskBadgeType.medium:
        return '~';
      case RiskBadgeType.high:
        return '!';
      case RiskBadgeType.urgent:
        return '!!!';
    }
  }

  EdgeInsets get _effectivePadding {
    if (padding != null) return padding!;
    switch (size) {
      case RiskBadgeSize.sm:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
      case RiskBadgeSize.lg:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  double get _textSize => size == RiskBadgeSize.sm ? 12 : 15;

  double get _iconCircleSize => size == RiskBadgeSize.sm ? 14 : 18;

  @override
  Widget build(BuildContext context) {
    final bandColor = _bandColor;
    final bgColor = bandColor.withValues(alpha:0.1);
    final borderColor = bandColor.withValues(alpha:0.6);
    final scoreSuffix = score != null ? ' · $score' : '';

    final semanticsLabel = score != null
        ? '$label risk, score $score'
        : '$label risk';

    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: _effectivePadding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon circle
            Container(
              width: _iconCircleSize,
              height: _iconCircleSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bandColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                _iconText,
                style: TextStyle(
                  fontSize: _iconCircleSize * (_iconText.length > 1 ? 0.45 : 0.65),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
            SizedBox(width: size == RiskBadgeSize.sm ? 6 : 8),
            // Label + optional score
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: _textSize,
                  fontWeight: FontWeight.w600,
                  color: bandColor,
                ),
                children: [
                  TextSpan(text: label),
                  if (score != null)
                    TextSpan(
                      text: scoreSuffix,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: bandColor.withValues(alpha:0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
