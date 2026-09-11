import 'package:dhealth/data/disorder_registry.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';

/// One live [ClinicalEvidence] row in a `*_clinical_data.dart` file.
class LiveClinicalEvidenceSite {
  /// DisorderRegistry key, e.g. `psoriasis` / `eczema`.
  final String conditionKey;

  /// Display name from [ClinicalDisorder.disorderName].
  final String conditionDisplayName;

  /// Slot inside the disorder, e.g. `Trigger: Psychological Stress`.
  final String location;

  /// 0-based index of this paper within [location] (disambiguates multiple
  /// papers on the same trigger/treatment).
  final int ordinal;

  final ClinicalEvidence evidence;

  const LiveClinicalEvidenceSite({
    required this.conditionKey,
    required this.conditionDisplayName,
    required this.location,
    required this.ordinal,
    required this.evidence,
  });

  /// Firestore `entryRef` for this live row.
  Map<String, dynamic> get entryRef => {
        'condition': conditionKey,
        'location': location,
        'ordinal': ordinal,
        'title': evidence.title,
      };

  String get displayRef {
    final base = '$conditionKey / $location';
    return ordinal == 0 ? base : '$base [#$ordinal]';
  }
}

/// Patient-facing trigger/treatment copy that sits next to a citation.
/// Not stored on every review doc; resolved from the live registry by
/// [ClinicalEvidenceCatalog.patientFacingTextFor].
class LivePatientFacingText {
  final String? mechanism;
  final String? preventionStrategy;

  const LivePatientFacingText({this.mechanism, this.preventionStrategy});
}

/// Walks every live ClinicalEvidence entry.
///
/// Disk scans live in `clinical_evidence_catalog_io.dart` so this file can
/// compile on Flutter Web (no `dart:io`).
class ClinicalEvidenceCatalog {
  static const knownClinicalDataFiles = {
    'psoriasis_clinical_data.dart',
    'eczema_clinical_data.dart',
  };

  /// Keep in lockstep with [DisorderRegistry.getDisorderByIndex] keys.
  static const registryKeys = ['psoriasis', 'eczema'];

  /// Mechanism / prevention text patients see for this `entryRef` slot.
  /// Empty for key-research-paper rows, which have no trigger copy.
  static LivePatientFacingText patientFacingTextFor({
    required String conditionKey,
    required String location,
  }) {
    if (conditionKey.isEmpty || location.isEmpty) {
      return const LivePatientFacingText();
    }
    try {
      final disorder = DisorderRegistry.getDisorder(conditionKey);
      const triggerPrefix = 'Trigger: ';
      const treatmentPrefix = 'Treatment: ';
      if (location.startsWith(triggerPrefix)) {
        final name = location.substring(triggerPrefix.length);
        for (final trigger in disorder.triggers) {
          if (trigger.name == name) {
            return LivePatientFacingText(
              mechanism: trigger.mechanism,
              preventionStrategy: trigger.preventionStrategy,
            );
          }
        }
      }
      if (location.startsWith(treatmentPrefix)) {
        final name = location.substring(treatmentPrefix.length);
        for (final treatment in disorder.treatments) {
          if (treatment.name == name) {
            return LivePatientFacingText(mechanism: treatment.mechanism);
          }
        }
      }
    } catch (_) {
      // Unknown condition or incomplete entryRef — nothing to attach.
    }
    return const LivePatientFacingText();
  }

  static List<LiveClinicalEvidenceSite> allLiveSites() {
    final sites = <LiveClinicalEvidenceSite>[];
    for (final key in registryKeys) {
      sites.addAll(sitesFor(key, DisorderRegistry.getDisorder(key)));
    }
    return sites;
  }

  static List<LiveClinicalEvidenceSite> sitesFor(
    String conditionKey,
    ClinicalDisorder disorder,
  ) {
    final sites = <LiveClinicalEvidenceSite>[];
    final display = disorder.disorderName;

    for (final trigger in disorder.triggers) {
      final location = 'Trigger: ${trigger.name}';
      for (var i = 0; i < trigger.evidence.length; i++) {
        sites.add(LiveClinicalEvidenceSite(
          conditionKey: conditionKey,
          conditionDisplayName: display,
          location: location,
          ordinal: i,
          evidence: trigger.evidence[i],
        ));
      }
    }
    for (final treatment in disorder.treatments) {
      final location = 'Treatment: ${treatment.name}';
      for (var i = 0; i < treatment.evidence.length; i++) {
        sites.add(LiveClinicalEvidenceSite(
          conditionKey: conditionKey,
          conditionDisplayName: display,
          location: location,
          ordinal: i,
          evidence: treatment.evidence[i],
        ));
      }
    }
    for (var i = 0; i < disorder.keyResearchPapers.length; i++) {
      sites.add(LiveClinicalEvidenceSite(
        conditionKey: conditionKey,
        conditionDisplayName: display,
        location: 'Key research paper',
        ordinal: i,
        evidence: disorder.keyResearchPapers[i],
      ));
    }
    return sites;
  }
}
