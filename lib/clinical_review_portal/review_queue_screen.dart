import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review_portal/portal_widgets.dart';
import 'package:dhealth/clinical_review_portal/review_detail_screen.dart';
import 'package:flutter/material.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({
    super.key,
    required this.service,
    required this.reviewedBy,
  });

  final ClinicalReviewPortalService service;
  final String reviewedBy;

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  String _condition = 'all';
  String _sort = 'submittedAt';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClinicalEvidenceReviewDoc>>(
      stream: widget.service.pendingReviews(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load queue: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var rows = List<ClinicalEvidenceReviewDoc>.from(snap.data!);
        if (_condition != 'all') {
          rows = rows.where((r) => r.conditionLabel == _condition).toList();
        }
        rows.sort((a, b) {
          switch (_sort) {
            case 'condition':
              return a.conditionLabel.compareTo(b.conditionLabel);
            case 'location':
              return a.locationLabel.compareTo(b.locationLabel);
            default:
              return (b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              );
          }
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Pending reviews',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${rows.length} item${rows.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(width: 24),
                    const Text('Condition'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _condition,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                          value: 'psoriasis',
                          child: Text('psoriasis'),
                        ),
                        DropdownMenuItem(
                          value: 'eczema',
                          child: Text('eczema'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _condition = v ?? 'all'),
                    ),
                    const SizedBox(width: 16),
                    const Text('Sort'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _sort,
                      items: const [
                        DropdownMenuItem(
                          value: 'submittedAt',
                          child: Text('Submitted date'),
                        ),
                        DropdownMenuItem(
                          value: 'condition',
                          child: Text('Condition'),
                        ),
                        DropdownMenuItem(
                          value: 'location',
                          child: Text('Location'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _sort = v ?? 'submittedAt'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No pending reviews.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('Condition')),
                          DataColumn(label: Text('Location')),
                          DataColumn(label: Text('Title')),
                          DataColumn(label: Text('Submitted')),
                          DataColumn(label: Text('By')),
                        ],
                        rows: [
                          for (final row in rows)
                            DataRow(
                              onSelectChanged: (_) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ReviewDetailScreen(
                                      service: widget.service,
                                      reviewId: row.id,
                                      reviewedBy: widget.reviewedBy,
                                    ),
                                  ),
                                );
                              },
                              cells: [
                                DataCell(Text(row.conditionLabel)),
                                DataCell(Text(row.locationLabel)),
                                DataCell(
                                  SizedBox(
                                    width: 360,
                                    child: Text(
                                      row.proposedTitle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(formatPortalTimestamp(row.submittedAt)),
                                ),
                                DataCell(Text(row.submittedBy ?? '—')),
                              ],
                            ),
                        ],
                      ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
