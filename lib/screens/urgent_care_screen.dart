import 'package:flutter/material.dart';

import 'package:dhealth/data/disorder_registry.dart';
import 'package:dhealth/widgets/urgent_care_section.dart';

/// Full-screen view of the static urgent-care guidance for [condition].
/// Opened from the always-on home-screen entry; not gated by FeatureFlags.
class UrgentCareScreen extends StatelessWidget {
  final String condition;

  const UrgentCareScreen({super.key, required this.condition});

  @override
  Widget build(BuildContext context) {
    final redFlags = DisorderRegistry.getDisorder(condition).redFlags;
    return Scaffold(
      appBar: AppBar(title: const Text('Urgent care')),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        children: [UrgentCareSection(redFlags: redFlags)],
      ),
    );
  }
}
