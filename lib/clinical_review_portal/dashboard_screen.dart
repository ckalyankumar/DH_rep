import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:dhealth/clinical_review_portal/portal_widgets.dart';
import 'package:flutter/material.dart';

/// Overview for clinicalAdmin: how many of the 29(+) citation-audit /
/// ongoing reviews are pending vs. decided, broken down by reviewer, plus
/// a feed of the most recent decisions. Read-only — all actions happen on
/// the Queue / Audit tabs, this is just "where things stand."
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.service});

  final ClinicalReviewPortalService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClinicalEvidenceReviewDoc>>(
      stream: service.allReviews(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load reviews: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snap.data!;
        final counts = <String, int>{
          ClinicalReviewSchema.statusPending: 0,
          ClinicalReviewSchema.statusApproved: 0,
          ClinicalReviewSchema.statusRejected: 0,
          ClinicalReviewSchema.statusNeedsChanges: 0,
        };
        for (final r in reviews) {
          counts[r.status] = (counts[r.status] ?? 0) + 1;
        }
        final total = reviews.length;
        final decided = total - (counts[ClinicalReviewSchema.statusPending] ?? 0);

        final byReviewer = <String, _ReviewerTally>{};
        for (final r in reviews) {
          if (r.reviewedBy == null || r.reviewedBy!.isEmpty) continue;
          final tally = byReviewer.putIfAbsent(
            r.reviewedBy!,
            () => _ReviewerTally(),
          );
          tally.total++;
          if (r.status == ClinicalReviewSchema.statusApproved) {
            tally.approved++;
          } else if (r.status == ClinicalReviewSchema.statusRejected) {
            tally.rejected++;
          } else if (r.status == ClinicalReviewSchema.statusNeedsChanges) {
            tally.needsChanges++;
          }
        }
        final reviewerRows = byReviewer.entries.toList()
          ..sort((a, b) => b.value.total.compareTo(a.value.total));

        final recent = [...reviews]
          ..sort((a, b) {
            final at = a.reviewedAt ?? a.submittedAt ?? DateTime(1970);
            final bt = b.reviewedAt ?? b.submittedAt ?? DateTime(1970);
            return bt.compareTo(at);
          });
        final recentDecided = recent
            .where((r) => r.status != ClinicalReviewSchema.statusPending)
            .take(10)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Review status across every submitted citation.',
              style: TextStyle(color: PortalTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(
                  label: 'Total submitted',
                  value: '$total',
                  color: PortalTheme.navy,
                ),
                _StatCard(
                  label: 'Pending',
                  value: '${counts[ClinicalReviewSchema.statusPending]}',
                  color: PortalTheme.pending,
                ),
                _StatCard(
                  label: 'Approved',
                  value: '${counts[ClinicalReviewSchema.statusApproved]}',
                  color: PortalTheme.approved,
                ),
                _StatCard(
                  label: 'Rejected',
                  value: '${counts[ClinicalReviewSchema.statusRejected]}',
                  color: PortalTheme.rejected,
                ),
                _StatCard(
                  label: 'Needs changes',
                  value: '${counts[ClinicalReviewSchema.statusNeedsChanges]}',
                  color: PortalTheme.needsChanges,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (total > 0) _ProgressBar(counts: counts, total: total),
            const SizedBox(height: 8),
            Text(
              total == 0
                  ? 'No reviews submitted yet.'
                  : '$decided of $total decided (${(decided / total * 100).round()}%).',
              style: const TextStyle(fontSize: 12, color: PortalTheme.muted),
            ),
            const SizedBox(height: 28),
            const Text(
              'By reviewer',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (reviewerRows.isEmpty)
              const Text(
                'No decisions recorded yet.',
                style: TextStyle(color: PortalTheme.muted),
              )
            else
              DataTable(
                columns: const [
                  DataColumn(label: Text('Reviewer')),
                  DataColumn(label: Text('Decided')),
                  DataColumn(label: Text('Approved')),
                  DataColumn(label: Text('Rejected')),
                  DataColumn(label: Text('Needs changes')),
                ],
                rows: [
                  for (final entry in reviewerRows)
                    DataRow(cells: [
                      DataCell(Text(entry.key)),
                      DataCell(Text('${entry.value.total}')),
                      DataCell(Text('${entry.value.approved}')),
                      DataCell(Text('${entry.value.rejected}')),
                      DataCell(Text('${entry.value.needsChanges}')),
                    ]),
                ],
              ),
            const SizedBox(height: 28),
            const Text(
              'Recent decisions',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (recentDecided.isEmpty)
              const Text(
                'Nothing decided yet — items are still in the queue.',
                style: TextStyle(color: PortalTheme.muted),
              )
            else
              for (final r in recentDecided) _RecentRow(review: r),
          ],
        );
      },
    );
  }
}

class _ReviewerTally {
  int total = 0;
  int approved = 0;
  int rejected = 0;
  int needsChanges = 0;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PortalTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: PortalTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.counts, required this.total});

  final Map<String, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    Widget segment(int count, Color color) {
      if (count == 0) return const SizedBox.shrink();
      return Expanded(
        flex: count,
        child: Container(height: 10, color: color),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          segment(
            counts[ClinicalReviewSchema.statusApproved] ?? 0,
            PortalTheme.approved,
          ),
          segment(
            counts[ClinicalReviewSchema.statusRejected] ?? 0,
            PortalTheme.rejected,
          ),
          segment(
            counts[ClinicalReviewSchema.statusNeedsChanges] ?? 0,
            PortalTheme.needsChanges,
          ),
          segment(
            counts[ClinicalReviewSchema.statusPending] ?? 0,
            PortalTheme.line,
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.review});

  final ClinicalEvidenceReviewDoc review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PortalTheme.line),
      ),
      child: Row(
        children: [
          StatusChip(status: review.status),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              review.proposedTitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            review.reviewedBy ?? '—',
            style: const TextStyle(fontSize: 12, color: PortalTheme.muted),
          ),
          const SizedBox(width: 10),
          Text(
            formatPortalTimestamp(review.reviewedAt),
            style: const TextStyle(fontSize: 12, color: PortalTheme.muted),
          ),
        ],
      ),
    );
  }
}
