import 'package:dhealth/clinical_review/clinical_evidence_catalog.dart';
import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:dhealth/clinical_review_portal/portal_widgets.dart';
import 'package:flutter/material.dart';

/// Whether Approve may be enabled. GRADE and verification notes are
/// independent gates — either one missing keeps the button disabled.
bool reviewApprovalEnabled({
  required bool busy,
  required String? grade,
  required String notes,
}) {
  if (busy) return false;
  if (grade == null || grade.trim().isEmpty) return false;
  return notes.trim().length >= ClinicalReviewSchema.approvalNotesMinLength;
}

/// Approve must look disabled (gray) until both gates pass. Never set
/// [ElevatedButton.styleFrom] `backgroundColor` alone — that paints the
/// enabled green onto the disabled state when `disabledBackgroundColor`
/// is omitted, which is what made GRADE-only look like an approve.
ButtonStyle reviewApproveButtonStyle() {
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return const Color(0xFFC5CDD6);
      }
      return PortalTheme.approved;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return PortalTheme.muted;
      }
      return Colors.white;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      return Colors.white.withValues(alpha: 0.12);
    }),
    elevation: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.disabled) ? 0.0 : 1.0;
    }),
  );
}

class ReviewDetailScreen extends StatefulWidget {
  const ReviewDetailScreen({
    super.key,
    required this.service,
    required this.reviewId,
    required this.reviewedBy,
  });

  final ClinicalReviewPortalService service;
  final String reviewId;
  final String reviewedBy;

  static const verificationNotesFieldKey = Key('verification-notes');
  static const approveButtonKey = Key('approve-review');

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  final _notes = TextEditingController();
  String? _grade;
  bool _notesSeeded = false;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _decide(String status) async {
    if (status == ClinicalReviewSchema.statusApproved &&
        !reviewApprovalEnabled(
          busy: false,
          grade: _grade,
          notes: _notes.text,
        )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final trimmed = _notes.text.trim();
      await widget.service.decideReview(
        reviewId: widget.reviewId,
        status: status,
        reviewedBy: widget.reviewedBy,
        reviewNotes: trimmed.isEmpty ? null : trimmed,
        gradeLevel: _grade,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save decision: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClinicalEvidenceReviewDoc?>(
      stream: widget.service.review(widget.reviewId),
      builder: (context, snap) {
        final review = snap.data;
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Review')),
            body: Center(child: Text('${snap.error}')),
          );
        }
        if (review == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Review')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!_notesSeeded) {
          _notesSeeded = true;
          final seededNotes = review.reviewNotes ?? '';
          final seededGrade = review.gradeLevel;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_notes.text != seededNotes) {
              _notes.value = TextEditingValue(text: seededNotes);
            }
            _grade ??= seededGrade;
            setState(() {});
          });
        }

        final proposed = review.proposedContent;
        final liveClaim = ClinicalEvidenceCatalog.patientFacingTextFor(
          conditionKey: review.conditionLabel,
          location: review.locationLabel,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(review.displayRef),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: StatusChip(status: review.status)),
              ),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      review.proposedTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${review.displayRef} · submitted '
                      '${formatPortalTimestamp(review.submittedAt)} by '
                      '${review.submittedBy ?? '—'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PortalTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    JudgmentSection(
                      title: 'SOURCE IDENTIFICATION',
                      prompt:
                          'First judgment: is this a real, correctly identified '
                          'paper? Open the DOI or PMID and confirm the '
                          'bibliographic identity before looking at any claim.',
                      accent: PortalTheme.navy,
                      child: LabeledValueTable(
                        rows: [
                          ('title', _plain(proposed['title'])),
                          ('authors', _plain(proposed['authors'])),
                          ('journal', _plain(proposed['journal'])),
                          ('year', _plain(proposed['year'])),
                          ('doi', _doiValue(proposed['doi'])),
                          ('pmid', _pmidValue(proposed['pmid'])),
                          ('url', _plain(proposed['url'])),
                          ('evidenceType', _plain(proposed['evidenceType'])),
                          (
                            'citationCount',
                            _plain(proposed['citationCount']),
                          ),
                          (
                            'gradeLevel (proposed)',
                            _plain(proposed['gradeLevel']),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    JudgmentSection(
                      title: 'CLINICAL CLAIM SHOWN TO PATIENTS',
                      prompt:
                          'Second judgment: does this patient-facing text '
                          'actually reflect what that source says? A real '
                          'citation is not enough. Approving without reading '
                          'the source for these fields is the failure mode '
                          'this review exists to catch.',
                      accent: const Color(0xFF9A3412),
                      child: LabeledValueTable(
                        rows: [
                          ('keyFinding', _plain(proposed['keyFinding'])),
                          (
                            'mechanism',
                            _plain(
                              _claimValue(
                                proposed['mechanism'],
                                liveClaim.mechanism,
                              ),
                            ),
                          ),
                          (
                            'preventionStrategy',
                            _plain(
                              _claimValue(
                                proposed['preventionStrategy'],
                                liveClaim.preventionStrategy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (review.isEdit) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Diff vs previous live content  (* = clinically compared)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Source identification',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PortalTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ContentDiffTable(
                        previous: review.previousContent ?? const {},
                        proposed: proposed,
                        fields: ContentDiffTable.sourceFields,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Clinical claim shown to patients',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PortalTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ContentDiffTable(
                        previous: _claimDiffMap(
                          review.previousContent ?? const {},
                          liveClaim,
                        ),
                        proposed: _claimDiffMap(proposed, liveClaim),
                        fields: ContentDiffTable.claimFields,
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'New entry — no previous live content.',
                          style: TextStyle(color: PortalTheme.muted),
                        ),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 340,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Decision',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('GRADE rating', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _grade,
                        hint: const Text('Select GRADE'),
                        items: [
                          for (final g in ClinicalReviewSchema.gradeLevels)
                            DropdownMenuItem(value: g, child: Text(g)),
                        ],
                        onChanged: review.isPending && !_busy
                            ? (v) => setState(() => _grade = v)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Verification notes (required)',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: TextField(
                          key: ReviewDetailScreen.verificationNotesFieldKey,
                          controller: _notes,
                          enabled: review.isPending && !_busy,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText:
                                'Briefly note how you confirmed this claim matches the source',
                            helperText:
                                'Required to Approve. Optional for Reject / Request changes.',
                            helperMaxLines: 3,
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!review.isPending)
                        Text(
                          'Already ${statusLabel(review.status)} by '
                          '${review.reviewedBy ?? '—'} at '
                          '${formatPortalTimestamp(review.reviewedAt)}.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PortalTheme.muted,
                          ),
                        )
                      else
                        ListenableBuilder(
                          listenable: _notes,
                          builder: (context, _) {
                            final canApprove = reviewApprovalEnabled(
                              busy: _busy,
                              grade: _grade,
                              notes: _notes.text,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton(
                                  key: ReviewDetailScreen.approveButtonKey,
                                  onPressed: canApprove
                                      ? () => _decide(
                                            ClinicalReviewSchema
                                                .statusApproved,
                                          )
                                      : null,
                                  style: reviewApproveButtonStyle(),
                                  child: const Text('Approve'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(
                                            ClinicalReviewSchema
                                                .statusNeedsChanges,
                                          ),
                                  child: const Text('Request changes'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(
                                            ClinicalReviewSchema
                                                .statusRejected,
                                          ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: PortalTheme.rejected,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _plain(Object? value) {
    final text = value == null ? '' : value.toString();
    return SelectableText(
      text.trim().isEmpty ? '—' : text,
      style: const TextStyle(fontSize: 13, height: 1.35),
    );
  }

  static Widget _doiValue(Object? value) {
    final text = value == null ? '' : value.toString();
    final uri = doiResolverUri(text);
    if (uri == null) return _plain(text);
    return SourceLink(
      key: const Key('source-link-doi'),
      uri: uri,
      text: text.trim(),
    );
  }

  static Widget _pmidValue(Object? value) {
    final text = value == null ? '' : value.toString();
    final uri = pubmedUri(text);
    if (uri == null) return _plain(text);
    return SourceLink(
      key: const Key('source-link-pmid'),
      uri: uri,
      text: text.trim(),
    );
  }

  static String _claimValue(Object? proposed, String? live) {
    final fromProposed = proposed?.toString().trim() ?? '';
    if (fromProposed.isNotEmpty) return fromProposed;
    return live?.trim() ?? '';
  }

  static Map<String, dynamic> _claimDiffMap(
    Map<String, dynamic> content,
    LivePatientFacingText live,
  ) {
    return {
      'keyFinding': content['keyFinding'],
      'mechanism': _claimValue(content['mechanism'], live.mechanism),
      'preventionStrategy':
          _claimValue(content['preventionStrategy'], live.preventionStrategy),
    };
  }
}
