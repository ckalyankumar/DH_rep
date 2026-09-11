import 'package:dhealth/clinical_review/clinical_review_schema.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/link.dart';

String formatPortalTimestamp(DateTime? value) {
  if (value == null) return '—';
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}

String statusLabel(String status) {
  switch (status) {
    case ClinicalReviewSchema.statusPending:
      return 'Pending';
    case ClinicalReviewSchema.statusApproved:
      return 'Approved';
    case ClinicalReviewSchema.statusRejected:
      return 'Rejected';
    case ClinicalReviewSchema.statusNeedsChanges:
      return 'Needs changes';
    default:
      return status;
  }
}

Color statusColor(String status) {
  switch (status) {
    case ClinicalReviewSchema.statusPending:
      return PortalTheme.pending;
    case ClinicalReviewSchema.statusApproved:
      return PortalTheme.approved;
    case ClinicalReviewSchema.statusRejected:
      return PortalTheme.rejected;
    case ClinicalReviewSchema.statusNeedsChanges:
      return PortalTheme.needsChanges;
    default:
      return PortalTheme.muted;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// DOI resolver URL, or null when the stored value cannot be opened.
Uri? doiResolverUri(String? doi) {
  var raw = doi?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.toUpperCase() == 'XXX') return null;
  if (raw.startsWith('https://doi.org/')) {
    raw = raw.substring('https://doi.org/'.length);
  } else if (raw.startsWith('http://doi.org/')) {
    raw = raw.substring('http://doi.org/'.length);
  } else if (raw.startsWith('https://dx.doi.org/')) {
    raw = raw.substring('https://dx.doi.org/'.length);
  } else if (raw.startsWith('http://dx.doi.org/')) {
    raw = raw.substring('http://dx.doi.org/'.length);
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return Uri.tryParse(raw);
  }
  return Uri.parse('https://doi.org/$raw');
}

/// PubMed URL, or null when [pmid] is not a numeric PubMed ID.
Uri? pubmedUri(String? pmid) {
  final raw = pmid?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(raw)) return null;
  return Uri.parse('https://pubmed.ncbi.nlm.nih.gov/$raw');
}

/// Opens [uri] in a new browser tab (web) / external app.
class SourceLink extends StatelessWidget {
  const SourceLink({
    super.key,
    required this.uri,
    required this.text,
  });

  final Uri uri;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Link(
      uri: uri,
      target: LinkTarget.blank,
      builder: (context, followLink) {
        return InkWell(
          onTap: followLink,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF155EEF),
              decoration: TextDecoration.underline,
            ),
          ),
        );
      },
    );
  }
}

/// One of the two distinct reviewer judgments on the Detail screen.
class JudgmentSection extends StatelessWidget {
  const JudgmentSection({
    super.key,
    required this.title,
    required this.prompt,
    required this.accent,
    required this.child,
  });

  final String title;
  final String prompt;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: PortalTheme.ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: child,
          ),
        ],
      ),
    );
  }
}

class LabeledValueTable extends StatelessWidget {
  const LabeledValueTable({super.key, required this.rows});

  final List<(String, Widget)> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: Text(
                  row.$1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PortalTheme.muted,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: row.$2,
              ),
            ],
          ),
      ],
    );
  }
}

class KeyValueTable extends StatelessWidget {
  const KeyValueTable({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: Text(
                  row.$1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PortalTheme.muted,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(
                  row.$2.isEmpty ? '—' : row.$2,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class ContentDiffTable extends StatelessWidget {
  const ContentDiffTable({
    super.key,
    required this.previous,
    required this.proposed,
    this.fields = defaultFields,
  });

  final Map<String, dynamic> previous;
  final Map<String, dynamic> proposed;
  final List<String> fields;

  static const sourceFields = [
    'title',
    'authors',
    'year',
    'journal',
    'doi',
    'pmid',
    'url',
    'evidenceType',
    'citationCount',
    'gradeLevel',
  ];

  static const claimFields = [
    'keyFinding',
    'mechanism',
    'preventionStrategy',
  ];

  static const defaultFields = [...sourceFields, ...claimFields];

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      border: TableBorder.all(color: PortalTheme.line),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFEEF2F6)),
          children: [
            _Head('Field'),
            _Head('Previous (live)'),
            _Head('Proposed'),
          ],
        ),
        for (final field in fields)
          _diffRow(field, '${previous[field] ?? ''}', '${proposed[field] ?? ''}'),
      ],
    );
  }

  TableRow _diffRow(String field, String before, String after) {
    final changed = before.trim() != after.trim();
    final clinical =
        ClinicalReviewSchema.clinicallyComparedFields.contains(field);
    return TableRow(
      decoration: BoxDecoration(
        color: changed ? const Color(0xFFFFF6E8) : Colors.white,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            clinical ? '$field *' : field,
            style: TextStyle(
              fontSize: 12,
              fontWeight: changed ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            before.isEmpty ? '—' : before,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            after.isEmpty ? '—' : after,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
