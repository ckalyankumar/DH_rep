import 'dart:io';

import 'package:dhealth/clinical_review/clinical_evidence_catalog.dart';

/// File-system scans used by the `dart run` enforcement scripts.
/// Not imported by the Flutter Web portal (`dart:io` is unavailable there).
class ClinicalEvidenceCatalogIo {
  static List<File> unregisteredClinicalDataFiles(Directory root) {
    final dir = Directory('${root.path}/lib/data');
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.replaceAll('\\', '/').endsWith('_clinical_data.dart'))
        .where((f) => !ClinicalEvidenceCatalog.knownClinicalDataFiles
            .contains(_basename(f.path)))
        .toList();
  }

  static List<String> strayClinicalEvidenceConstructors(Directory root) {
    final lib = Directory('${root.path}/lib');
    final ctor = RegExp(r'ClinicalEvidence\s*\(');
    final hits = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'.*/lib/'), 'lib/');
      if (rel.endsWith('clinical_evidence_models.dart')) continue;
      if (ClinicalEvidenceCatalog.knownClinicalDataFiles.any(rel.endsWith)) {
        continue;
      }
      final text = entity.readAsStringSync();
      if (ctor.hasMatch(text)) {
        hits.add(rel);
      }
    }
    return hits;
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }
}
