import 'package:dhealth/models/recommendation_model.dart';

/// Exports recommendations to CSV for dermatologist review (pilot-ready).
/// Columns: id, title, rationale, steps, benefits, evidence, source, pmid, doi, grade, category, type
class RecommendationExportService {
  /// Generate CSV string for dermatologist review (UTF-8)
  static String toCsv(List<Recommendation> recommendations) {
    const csvHeader =
        'id,title,rationale,steps,benefits,evidence,source,pmid,doi,gradeLevel,category,type';
    final rows = <String>[csvHeader];

    for (final rec in recommendations) {
      final steps = rec.steps.join('; ').replaceAll(',', ';').replaceAll('\n', ' ');
      final category = rec.selfCareCategory?.name ?? '';
      final type = rec.type.name;

      rows.add(
        [
          rec.id,
          _escapeCsv(rec.title),
          _escapeCsv(rec.rationale),
          _escapeCsv(steps),
          _escapeCsv(rec.benefits),
          _escapeCsv(rec.evidence),
          _escapeCsv(rec.source),
          rec.pmid ?? '',
          rec.doi ?? '',
          rec.gradeLevel ?? '',
          category,
          type,
        ].join(','),
      );
    }

    return rows.join('\n');
  }

  static String _escapeCsv(String value) {
    if (value.isEmpty) return '';
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
