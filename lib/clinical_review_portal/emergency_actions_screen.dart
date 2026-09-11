import 'package:dhealth/clinical_review/clinical_evidence_catalog.dart';
import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:dhealth/clinical_review_portal/portal_widgets.dart';
import 'package:flutter/material.dart';

class EmergencyActionsScreen extends StatefulWidget {
  const EmergencyActionsScreen({
    super.key,
    required this.service,
    required this.actionBy,
  });

  final ClinicalReviewPortalService service;
  final String actionBy;

  @override
  State<EmergencyActionsScreen> createState() => _EmergencyActionsScreenState();
}

class _EmergencyActionsScreenState extends State<EmergencyActionsScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClinicalEvidenceReviewDoc>>(
      stream: widget.service.allReviews(),
      builder: (context, reviewSnap) {
        return StreamBuilder<List<EmergencyActionDoc>>(
          stream: widget.service.emergencyActions(),
          builder: (context, actionSnap) {
            if (reviewSnap.hasError || actionSnap.hasError) {
              return Center(
                child: Text(
                  'Could not load emergency data: ${reviewSnap.error ?? actionSnap.error}',
                ),
              );
            }
            if (!reviewSnap.hasData || !actionSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final live = ClinicalEvidenceCatalog.allLiveSites();
            final approved = widget.service.approvedLiveEntries(
              liveSites: live,
              reviews: reviewSnap.data!,
              actions: actionSnap.data!,
            );
            final open = actionSnap.data!
                .where((a) => a.isOpenDisable)
                .toList();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Emergency actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Disable an already-approved live entry. Resolution is a '
                  'human decision — nothing auto-reverts after 72 hours.',
                  style: TextStyle(color: PortalTheme.muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Text(
                  'Open disables (${open.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (open.isEmpty)
                  const Text('None open.')
                else
                  for (final action in open) _OpenDisableCard(
                    action: action,
                    onResolve: (resolution) async {
                      try {
                        await widget.service.resolveEmergency(
                          actionId: action.id,
                          resolution: resolution,
                          resolvedBy: widget.actionBy,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not resolve: $e')),
                        );
                      }
                    },
                  ),
                const SizedBox(height: 28),
                Text(
                  'Approved live entries (${approved.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (approved.isEmpty)
                  const Text(
                    'No live dart entries currently match an approved review. '
                    'That is expected until the first clinical sign-off lands.',
                  )
                else
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Condition')),
                      DataColumn(label: Text('Location')),
                      DataColumn(label: Text('Title')),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final site in approved)
                        DataRow(
                          cells: [
                            DataCell(Text(site.conditionKey)),
                            DataCell(Text(site.location)),
                            DataCell(
                              SizedBox(
                                width: 360,
                                child: Text(
                                  site.evidence.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () => _confirmDisable(site),
                                child: const Text('Disable'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDisable(LiveClinicalEvidenceSite site) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable live entry'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(site.displayRef),
              const SizedBox(height: 8),
              Text(site.evidence.title),
              const SizedBox(height: 16),
              TextField(
                controller: reason,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create disable'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true) return;
    if (text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A reason is required.')),
      );
      return;
    }
    try {
      await widget.service.createDisable(
        entryRef: site.entryRef,
        reason: text,
        actionBy: widget.actionBy,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create disable: $e')),
      );
    }
  }
}

class _OpenDisableCard extends StatelessWidget {
  const _OpenDisableCard({
    required this.action,
    required this.onResolve,
  });

  final EmergencyActionDoc action;
  final Future<void> Function(String resolution) onResolve;

  @override
  Widget build(BuildContext context) {
    final overdue = action.resolveBy != null &&
        action.resolveBy!.isBefore(DateTime.now().toUtc());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${action.condition ?? '—'} / ${action.location ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(action.title ?? ''),
            const SizedBox(height: 6),
            Text('Reason: ${action.reason ?? '—'}'),
            Text(
              'By ${action.actionBy ?? '—'} at ${formatPortalTimestamp(action.actionAt)} · '
              'resolveBy ${formatPortalTimestamp(action.resolveBy)}'
              '${overdue ? '  OVERDUE' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: overdue ? PortalTheme.overdue : PortalTheme.muted,
                fontWeight: overdue ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () =>
                      onResolve(ClinicalReviewSchema.resolutionRestored),
                  child: const Text('Restore'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => onResolve(
                    ClinicalReviewSchema.resolutionRevokedPermanently,
                  ),
                  child: const Text('Revoke permanently'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
