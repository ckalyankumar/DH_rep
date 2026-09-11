# Clinical Evidence Review System

Compliance-grade gate: no `ClinicalEvidence` citation, `keyFinding`, or GRADE
rating may exist in the live app without a named human approval in Firestore.

This is the structural fix for the citation audit in
[`CITATION_AUDIT.md`](CITATION_AUDIT.md) /
[`CLINICIAN_REVIEW_PACKET.md`](CLINICIAN_REVIEW_PACKET.md). Those documents
remain the clinical review of *current* psoriasis/eczema data. This system
prevents the same class of silent fabrication from landing again.

**Do not edit** `lib/data/psoriasis_clinical_data.dart` or
`lib/data/eczema_clinical_data.dart` as part of standing up this system.

## Phase 1 status

Schema, security rules, and the enforcement script — approved.

Phase 2 (this document, Flutter web portal) is implemented. CI wiring is
Phase 3.

---

## Who may do what

| Role | Stored at | How it is granted | Capabilities |
|---|---|---|---|
| any authenticated user | Firebase Auth session | sign-in | **Create** a `clinicalEvidenceReviews` doc with `status: 'pending'` only. Cannot set `reviewedBy`, `reviewedAt`, top-level `gradeLevel`, or any status other than `pending`. |
| `clinicalReviewer` | `users/{uid}.profile.role` | Firebase console / Admin SDK | Read all reviews and emergency actions. Update a **pending** review: notes, GRADE, Approve / Reject / Request Changes. |
| `clinicalAdmin` | `users/{uid}.profile.role` | Firebase console / Admin SDK (start with the project owner) | Everything a reviewer can do, plus create and resolve `clinicalEvidenceEmergencyActions`. |

`patient` and `doctor` stay as they are. The login flow may only write those
two values. Rules **reject** a client write that sets `clinicalReviewer` or
`clinicalAdmin`, so nobody can self-escalate. To grant a reviewer: in the
Firebase console, set `users/{theirUid}.profile.role` to `clinicalReviewer`
or `clinicalAdmin`. Adding more people later is the same field.

### Why any authenticated user may submit (not a special "submitter" role)

The safety mechanism is **approval**, not submission. Engineers and AI coding
sessions need to file a pending review for a dart-file change without first
being made `clinicalReviewer`. If only staff could create reviews, the
easy path would be "skip Firestore and edit the dart file" — which is exactly
what this system exists to catch. Patients/doctors submitting noise is
possible but low-impact: they cannot approve, and the queue is staff-only to
read. The enforcement script still fails the PR until a named reviewer
approves matching content.

---

## Firestore schema

### `clinicalEvidenceReviews/{reviewId}`

| Field | Type | Notes |
|---|---|---|
| `status` | `'pending' \| 'approved' \| 'rejected' \| 'needs_changes'` | Create must be `pending`. Terminal states are immutable (audit trail). Resubmit as a **new** document. |
| `entryRef` | map | Identifies the live slot. See below. |
| `proposedContent` | map | Full `ClinicalEvidence` fields. Immutable after create. |
| `previousContent` | map \| null | Live content this edit replaces; `null` for a new entry. Immutable after create. |
| `submittedBy` | string | Person id/name, or an AI session identifier. Immutable. |
| `submittedAt` | timestamp | Must be `request.time` (server timestamp) on create. |
| `reviewedBy` | string \| null | Null on create. Set on Approve / Reject / Request Changes. |
| `reviewedAt` | timestamp \| null | Null on create. Server timestamp on decision. |
| `reviewNotes` | string \| null | Reviewer's free-text notes / requested edits. |
| `gradeLevel` | string \| null | **Reviewer-assigned** GRADE (`1A`, `1B`, `2A`, `2B`, `3`, `4`). Null on create; required when status becomes `approved`. |

#### `entryRef`

```
{
  "condition": "psoriasis",          // DisorderRegistry key: psoriasis | eczema
  "location": "Trigger: Psychological Stress",
  "ordinal": 0,                      // 0-based index when a slot has multiple papers
  "title": "Triggers for the onset and recurrence of psoriasis: …"
}
```

`condition` + `location` follow the existing citation walker (`Trigger: {name}`,
`Treatment: {name}`, `Key research paper`). `ordinal` and `title` disambiguate
multiple papers on the same trigger. The enforcement matcher uses
`condition` + `location` plus clinical field equality (so reordering papers
does not orphan an approval of the same content).

#### `proposedContent`

Every `ClinicalEvidence` field:

`title`, `authors`, `year`, `journal`, `doi`, `pmid`, `url`, `keyFinding`,
`citationCount`, `evidenceType`, `gradeLevel`.

The enforcement script compares **only** the clinically material fields:

`title`, `authors`, `doi`, `pmid`, `keyFinding`, `gradeLevel`.

`pmid` null and `""` are treated as equal. Live `gradeLevel` is compared to
the review document's top-level `gradeLevel` when that is set, otherwise to
`proposedContent.gradeLevel`. Incidental fields (`url`, `year`, `journal`,
`citationCount`, `evidenceType`) are stored for the reviewer and ignored by
the matcher.

Any previously approved review whose clinical fields still match counts —
not only the latest. If version A was approved and is now considered wrong,
reject/supersede it with a new review or file an emergency disable; do not
leave A approved if it must not ship.

### `clinicalEvidenceEmergencyActions/{actionId}`

| Field | Type | Notes |
|---|---|---|
| `entryRef` | map | Same shape as reviews. `title` optional; if omitted, the disable covers every paper at that `condition` + `location`. |
| `action` | `'disable' \| 'restore'` | `disable` is what the enforcement script looks for. |
| `actionBy` | string | Admin id/name. Immutable. |
| `actionAt` | timestamp | Server timestamp on create. Immutable. |
| `reason` | string | Required, non-empty. Immutable. |
| `resolveBy` | timestamp | `actionAt + 72 hours`, written at create so open disables are queryable by deadline. |
| `resolution` | `'revoked-permanently' \| 'restored' \| null` | Null while open. Set once; then immutable. |
| `resolvedBy` / `resolvedAt` | string / timestamp \| null | Set when resolving. |

An **open disable** is `action == 'disable'` and `resolution` null/absent.

### 72-hour window — no automatic revert

A disable must be resolved through the normal review flow within 72 hours.
`resolveBy` makes that deadline visible (portal + queries). **The system does
not auto-restore when the window lapses.** Auto-revert would put a still-wrong
claim back in front of patients because a clock expired, not because a human
decided the claim was safe. An overdue open disable is a process failure:
keep the live entry failing the enforcement script until a person explicitly
sets `resolution` to `restored` or `revoked-permanently` (and, if revoked,
removes or replaces the dart row via an approved review).

---

## Security rules (summary)

Added to `firestore.rules`:

- `users/{uid}` create/update cannot set `profile.role` to a protected
  clinical role. Existing `clinicalAdmin` / `clinicalReviewer` cannot be
  overwritten to `patient`/`doctor` by the client (so the mobile login flow
  cannot clobber the project owner's admin role).
- `clinicalEvidenceReviews`: signed-in create if `reviewCreateValid()`;
  staff read; staff update if `reviewUpdateValid()`; no deletes.
- `clinicalEvidenceEmergencyActions`: staff read; `clinicalAdmin` create/resolve;
  no deletes.

Deploy (when you are ready — not done as part of Phase 1 unless you ask):

```
firebase deploy --only firestore:rules,firestore:indexes
```

---

## Enforcement script

```
dart run tool/verify_clinical_evidence_reviews.dart
```

Not part of `flutter test`. Offline matching tests live in
`test/clinical_review/clinical_evidence_compliance_test.dart`
(`fake_cloud_firestore`).

The script:

1. Walks every live `ClinicalEvidence` in the two `*_clinical_data.dart`
   files (same catalog as `tool/verify_citation_identifiers.dart`).
2. Lists `clinicalEvidenceReviews` and `clinicalEvidenceEmergencyActions`
   from Firestore.
3. For each live row, requires an `approved` review whose `entryRef`
   matches and whose clinical fields match exactly.
4. If an open `disable` covers the row, flags `disabled-unresolved`
   (still exit 1, because the claim is still in the dart files).
5. Exit **1** on any of: never-reviewed, content-mismatch,
   disabled-unresolved, or a new clinical-data file the catalog does not
   know about.
6. Exit **2** if Firestore cannot be read (auth/network).

### Firestore target

| Env | Meaning |
|---|---|
| `FIRESTORE_EMULATOR_HOST` | Emulator (e.g. `localhost:8080`). No auth. Empty collections ⇒ every live row fails `never-reviewed`. |
| `FIRESTORE_ACCESS_TOKEN` | Bearer token for production project `dhealth-fb17e`. |
| `FIREBASE_PROJECT_ID` | Override project id (default `dhealth-fb17e`). |
| gcloud ADC | `gcloud auth application-default print-access-token` if installed. |

Today there are no approved reviews. A run against an empty emulator or
empty production collections **should fail extensively**. That is the gate
working, not a bug. Do not "fix" it by editing clinical data files.

Identifier resolution remains a separate job:

```
dart run tool/verify_citation_identifiers.dart
```

---

## Phase 2 — Flutter Web review portal

Distinct entry point (not the patient/doctor app):

```
flutter run -d chrome -t lib/clinical_review_portal/main.dart
```

### Access path (rules apply)

The portal uses **Firebase Auth ID tokens + the `cloud_firestore` SDK**
(`FirebaseFirestore.instance`). `request.auth` is set, so `firestore.rules`
run: only `clinicalReviewer` / `clinicalAdmin` can read the queue or decide
reviews; only `clinicalAdmin` can create emergency actions.

This is the opposite of the CI/enforcement script, which uses a Google OAuth
IAM token against the REST API and **bypasses** rules. The portal must not
be pointed at that client.

Login does **not** write `profile.role`. A signed-in patient or doctor sees
only “You don’t have access.”

### Screens

1. Login (email/password + Google) — same Firebase Auth project as mobile.
2. Review queue — pending items, filter by condition, sort by date/location.
3. Review detail — proposed fields, previousContent diff on edits, notes,
   GRADE selector, Approve / Reject / Request changes.
4. Audit — every review, any status, searchable.
5. Emergency (admin only) — open disables with 72h `resolveBy`, restore or
   revoke-permanently; disable an already-approved live dart entry with a
   required reason.
