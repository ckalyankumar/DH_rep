import 'package:flutter/material.dart';

import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:dhealth/widgets/clinical_note_widget.dart'
    show ClinicalNoteType, ClinicalNoteWidget, showWhenToSeeDoctorModal;

/// Static "When to Seek Urgent Care" guidance built from a disorder's
/// [RedFlag] list (e.g. `DisorderRegistry.getDisorder(c).redFlags`).
///
/// This is reference content, not computed interpretation: it must never be
/// gated by FeatureFlags. Shared by RecommendationsScreen and the home-screen
/// urgent-care entry so both always show the same text.
class UrgentCareSection extends StatelessWidget {
  final List<RedFlag> redFlags;

  const UrgentCareSection({super.key, required this.redFlags});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'When to Seek Urgent Care',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2c3e50),
            ),
          ),
          const SizedBox(height: 12),
          ...redFlags.map((flag) {
            final body = StringBuffer(
              '${flag.whyImportant}\n\nAction: ${flag.actionToTake}',
            );
            if (flag.guidelineSource != null) {
              body.write('\n\nSource: ${flag.guidelineSource}');
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClinicalNoteWidget(
                type: ClinicalNoteType.redFlag,
                title: flag.symptom,
                body: body.toString(),
                actionLabel: 'Learn more',
                onAction: () => showWhenToSeeDoctorModal(context),
              ),
            );
          }),
        ],
      ),
    );
  }
}
