import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/utils/spacing.dart';

/// Emoji for trigger category.
String _emojiForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'stress':
      return '😰';
    case 'sleep':
      return '😴';
    case 'diet':
      return '🍽️';
    case 'environment':
      return '🌡️';
    default:
      return '📊';
  }
}

/// Plain-language heading for correlation (no "correlation" or "Spearman" in heading).
String _headingForCorrelation(TriggerProCorrelation c, String condition) {
  final cat = c.category.toLowerCase();
  final scoreName = condition == 'eczema' ? 'POEM' : 'DLQI';
  final positive = c.r > 0;

  if (cat == 'stress' && positive) {
    return 'On high-stress weeks, your $scoreName is significantly worse';
  }
  if (cat == 'sleep' && positive) {
    return 'Poor sleep weeks show higher $scoreName scores';
  }
  if (cat == 'diet' && positive) {
    return 'Diet-related weeks link to worse skin scores';
  }
  if (cat == 'environment' && positive) {
    return 'Environmental triggers appear to worsen your skin scores';
  }
  // Fallback for other categories or negative correlation
  if (positive) {
    return 'Higher $cat weeks link to worse $scoreName scores';
  }
  return 'Lower $cat weeks link to better skin scores';
}

/// Risk band color based on avgProHigh (higher PRO = worse).
Color _borderColorForAvgPro(double avgProHigh) {
  if (avgProHigh >= 15) return AppTheme.riskHigh;
  if (avgProHigh >= 8) return AppTheme.riskMed;
  return AppTheme.riskLow;
}

/// Display label for category.
String _categoryLabel(String category) {
  return category[0].toUpperCase() + category.substring(1).toLowerCase();
}

/// Card showing the most significant trigger–PRO correlation as a plain-language insight.
class TriggerInsightCard extends StatelessWidget {
  final TriggerProCorrelation correlation;
  final String condition;

  const TriggerInsightCard({
    super.key,
    required this.correlation,
    required this.condition,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColorForAvgPro(correlation.avgProHigh);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border(
          left: BorderSide(width: 4, color: borderColor),
        ),
      ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: emoji + "Based on your data" chip
              Row(
                children: [
                  Text(
                    _emojiForCategory(correlation.category),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Based on your data',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Heading
              Text(
                _headingForCorrelation(correlation, condition),
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Effect size row: High/Low boxes with arrow
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppTheme.riskHigh.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'High ${_categoryLabel(correlation.category)} weeks',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${correlation.avgProHigh.toStringAsFixed(1)} avg',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppTheme.riskLow.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Low ${_categoryLabel(correlation.category)} weeks',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${correlation.avgProLow.toStringAsFixed(1)} avg',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Footer: ρ and weeks
              Text(
                'ρ = ${correlation.r.toStringAsFixed(2)} · ${correlation.weeks} weeks of data',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '📊 Statistical association · Not a diagnosis',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
