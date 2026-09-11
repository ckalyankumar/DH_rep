import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review_portal/portal_widgets.dart';
import 'package:dhealth/clinical_review_portal/review_detail_screen.dart';
import 'package:flutter/material.dart';

class AuditHistoryScreen extends StatefulWidget {
  const AuditHistoryScreen({
    super.key,
    required this.service,
    required this.reviewedBy,
  });

  final ClinicalReviewPortalService service;
  final String reviewedBy;

  @override
  State<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends State<AuditHistoryScreen> {
  String _query = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClinicalEvidenceReviewDoc>>(
      stream: widget.service.allReviews(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load history: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final q = _query.trim().toLowerCase();
        final rows = snap.data!.where((r) {
          if (_status != 'all' && r.status != _status) return false;
          if (q.isEmpty) return true;
          final hay = [
            r.displayRef,
            r.proposedTitle,
            r.submittedBy,
            r.reviewedBy,
            r.status,
            r.reviewNotes,
            r.id,
          ].whereType<String>().join(' ').toLowerCase();
          return hay.contains(q);
        }).toList();

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
                      'Audit trail',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText:
                              'Search title, location, submitter, notes…',
                          prefixIcon: Icon(Icons.search, size: 18),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All statuses'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected'),
                        ),
                        DropdownMenuItem(
                          value: 'needs_changes',
                          child: Text('Needs changes'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'all'),
                    ),
                    const SizedBox(width: 16),
                    Text('${rows.length} of ${snap.data!.length}'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No matching reviews.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Condition')),
                          DataColumn(label: Text('Location')),
                          DataColumn(label: Text('Title')),
                          DataColumn(label: Text('Submitted')),
                          DataColumn(label: Text('Reviewed')),
                          DataColumn(label: Text('GRADE')),
                          DataColumn(label: Text('Verification notes')),
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
                                DataCell(StatusChip(status: row.status)),
                                DataCell(Text(row.conditionLabel)),
                                DataCell(Text(row.locationLabel)),
                                DataCell(
                                  SizedBox(
                                    width: 280,
                                    child: Text(
                                      row.proposedTitle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(formatPortalTimestamp(row.submittedAt)),
                                ),
                                DataCell(
                                  Text(
                                    row.reviewedBy == null
                                        ? '—'
                                        : '${row.reviewedBy}\n${formatPortalTimestamp(row.reviewedAt)}',
                                  ),
                                ),
                                DataCell(Text(row.gradeLevel ?? '—')),
                                DataCell(
                                  SizedBox(
                                    width: 280,
                                    child: Text(
                                      (row.reviewNotes ?? '').trim().isEmpty
                                          ? '—'
                                          : row.reviewNotes!,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
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
