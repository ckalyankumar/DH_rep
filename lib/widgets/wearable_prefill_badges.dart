import 'package:flutter/material.dart';

import 'package:dhealth/utils/theme.dart';

/// Shown on wearable-sourced fields that haven't been changed.
class WearableBadge extends StatelessWidget {
  final String provider;

  const WearableBadge({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final displayName =
        provider.isEmpty ? provider : '${provider[0].toUpperCase()}${provider.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.wearableBlue.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '⌚ $displayName',
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.wearableBlue,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Shown after user overrides a pre-filled value.
class ManualBadge extends StatelessWidget {
  const ManualBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.textMuted.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '✏️ You',
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
