import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review/reviewer_access_request.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:flutter/material.dart';

/// clinicalAdmin-only: approve/reject pending reviewer-access requests and
/// see who currently holds clinicalReviewer / clinicalAdmin. The actual
/// role grant/revoke always goes through a Cloud Function — see
/// ClinicalReviewPortalService's approveReviewerRequest / etc.
class ReviewersScreen extends StatelessWidget {
  const ReviewersScreen({super.key, required this.service});

  final ClinicalReviewPortalService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewerAccessRequestDoc>>(
      stream: service.reviewerAccessRequests(),
      builder: (context, reqSnap) {
        return StreamBuilder<List<ClinicalStaffUser>>(
          stream: service.clinicalStaffUsers(),
          builder: (context, staffSnap) {
            if (reqSnap.hasError || staffSnap.hasError) {
              return Center(
                child: Text(
                  'Could not load reviewer data: ${reqSnap.error ?? staffSnap.error}',
                ),
              );
            }
            if (!reqSnap.hasData || !staffSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = reqSnap.data!;
            final pending = requests.where((r) => r.isPending).toList();
            final decided = requests.where((r) => !r.isPending).toList();
            final staff = staffSnap.data!;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Reviewers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Approve access requests and manage who can review '
                  'citations. Granting or revoking clinicalReviewer always '
                  'runs server-side — this screen never writes the role '
                  'directly.',
                  style: TextStyle(color: PortalTheme.muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pending requests (${pending.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (pending.isEmpty)
                  const Text(
                    'No open requests.',
                    style: TextStyle(color: PortalTheme.muted),
                  )
                else
                  for (final req in pending)
                    _PendingRequestCard(service: service, request: req),
                const SizedBox(height: 28),
                Text(
                  'Current staff (${staff.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (staff.isEmpty)
                  const Text(
                    'No clinicalReviewer/clinicalAdmin accounts found.',
                    style: TextStyle(color: PortalTheme.muted),
                  )
                else
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Email / UID')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final user in staff)
                        DataRow(cells: [
                          DataCell(Text(user.email ?? user.uid)),
                          DataCell(_RoleChip(role: user.role)),
                          DataCell(
                            user.role == 'clinicalReviewer'
                                ? TextButton(
                                    onPressed: () =>
                                        _confirmRevoke(context, user),
                                    child: const Text('Revoke'),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ]),
                    ],
                  ),
                if (decided.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Decided requests (${decided.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Requester')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Decided by')),
                    ],
                    rows: [
                      for (final req in decided)
                        DataRow(cells: [
                          DataCell(Text(req.email)),
                          DataCell(_RoleChip(role: req.status)),
                          DataCell(Text(req.decidedBy ?? '—')),
                        ]),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    ClinicalStaffUser user,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke reviewer access'),
        content: Text(
          'Remove clinicalReviewer access for ${user.email ?? user.uid}? '
          'They will be set back to the patient role.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await service.revokeClinicalReviewer(user.uid);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not revoke: $e')),
      );
    }
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({required this.service, required this.request});

  final ClinicalReviewPortalService service;
  final ReviewerAccessRequestDoc request;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.displayName != null
                  ? '${request.displayName} · ${request.email}'
                  : request.email,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (request.note != null) ...[
              const SizedBox(height: 4),
              Text(request.note!),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _approve(context),
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _reject(context),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    try {
      await service.approveReviewerRequest(request.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.email} is now a clinicalReviewer.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve: $e')),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final text = note.text;
    note.dispose();
    if (ok != true) return;
    try {
      await service.rejectReviewerRequest(request.id, note: text);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reject: $e')),
      );
    }
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (role) {
      case 'clinicalAdmin':
        color = PortalTheme.navy;
        break;
      case 'clinicalReviewer':
      case 'approved':
        color = PortalTheme.approved;
        break;
      case 'rejected':
        color = PortalTheme.rejected;
        break;
      default:
        color = PortalTheme.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        role,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
