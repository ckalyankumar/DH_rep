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

## Status

| Phase | What | State |
|---|---|---|
| 1 | Schema, security rules, enforcement script | Approved |
| 2 | Flutter web review portal | Implemented |
| 3 | GitHub Actions CI | Workflow at [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). Requires a one-time GCP + GitHub secrets setup (below) before the Firestore job can authenticate. |

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

Both scripts run in CI (Phase 3). They are not part of `flutter test`.

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

---

## Phase 3 — CI

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

Runs on every **push** and **pull_request** targeting `main`. Four jobs, all
required for a green workflow (none use `continue-on-error`):

| Job | Command | Needs |
|---|---|---|
| Analyze | `flutter analyze` | Flutter |
| Test | `flutter test` (full suite) | Flutter |
| Verify citation identifiers | `dart run tool/verify_citation_identifiers.dart` | Outbound HTTPS to Crossref and Europe PMC |
| Verify clinical evidence reviews | `dart run tool/verify_clinical_evidence_reviews.dart` | Read-only production Firestore (`dhealth-fb17e`) |

Jobs are **separate GitHub checks** on purpose. If the review-compliance job
is red because entries are still `never-reviewed`, Analyze / Test can still
show green. Do not collapse them into one step.

The identifier job may also fail on current data: [`CITATION_AUDIT.md`](CITATION_AUDIT.md)
found fabricated / non-resolving DOIs in the paused psoriasis/eczema files.
That is the same clinical backlog, not a broken workflow. Do not edit those
dart files to make CI green.

`pubspec.yaml` lists `.env` as an asset and `.env` is gitignored. CI writes a
dummy `.env` with empty keys before `flutter pub get` so asset resolution
succeeds. That file is not committed.

### How the compliance job gets a Firestore token

`tool/verify_clinical_evidence_reviews.dart` credential order:

1. `FIRESTORE_EMULATOR_HOST` — not used in CI (would treat empty collections
   as every row `never-reviewed`, and would not prove production).
2. **`FIRESTORE_ACCESS_TOKEN`** — used in CI.
3. `gcloud auth application-default print-access-token`
4. `gcloud auth print-access-token`

CI does **not** install `gcloud`. It uses
[`google-github-actions/auth`](https://github.com/google-github-actions/auth)
with Workload Identity Federation and `token_format: access_token`. That
mints a short-lived OAuth token for the CI service account. The workflow
passes it in as `FIRESTORE_ACCESS_TOKEN`.

This path **bypasses** `firestore.rules` (Google IAM token against the REST
API), same as a local `gcloud` run. The service account must therefore be
read-only. It is **not** a clinical reviewer and cannot approve anything.

Fork pull requests do not receive repository secrets; the compliance job is
skipped on forks. Same-repo PRs and pushes to `main` still run.

### Credential choice: Workload Identity Federation, not a JSON key

A downloaded service-account JSON key is a long-lived secret: anyone who
copies it can list production Firestore until you rotate it. WIF lets GitHub
OIDC impersonate the service account for one job; there is no JSON key to
store. For a single-repo project the extra setup is a handful of `gcloud`
commands (pool, OIDC provider, IAM binding). That is not substantially harder
than uploading a key, so this repo uses WIF.

Do **not** generate a key in Firebase Console → Project settings → Service
accounts. That Firebase Admin SDK key is far more privileged than
`datastore.viewer`.

### One-time GCP setup (you do this)

Project: `dhealth-fb17e`.
Service account: `clinical-evidence-ci@dhealth-fb17e.iam.gserviceaccount.com`.
Role on the project: **only** `roles/datastore.viewer` (Cloud Datastore
Viewer).

Replace `OWNER/REPO` with this GitHub repository (e.g. `your-user/dhealth`).
The attribute condition must be this repo, not the whole GitHub org.

#### A. Enable APIs

```
gcloud config set project dhealth-fb17e

gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  firestore.googleapis.com
```

#### B. Create the service account and grant Datastore Viewer

**gcloud:**

```
gcloud iam service-accounts create clinical-evidence-ci \
  --project=dhealth-fb17e \
  --display-name="Clinical evidence CI (read-only Firestore)" \
  --description="GitHub Actions: list clinicalEvidenceReviews and clinicalEvidenceEmergencyActions. No write."

gcloud projects add-iam-policy-binding dhealth-fb17e \
  --member="serviceAccount:clinical-evidence-ci@dhealth-fb17e.iam.gserviceaccount.com" \
  --role="roles/datastore.viewer"
```

Confirm the SA has no other project roles:

```
gcloud projects get-iam-policy dhealth-fb17e \
  --flatten="bindings[].members" \
  --filter="bindings.members:clinical-evidence-ci@dhealth-fb17e.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

Expect a single row: `roles/datastore.viewer`.

**Google Cloud Console (same result):**

1. Open [IAM → Service accounts](https://console.cloud.google.com/iam-admin/serviceaccounts?project=dhealth-fb17e)
   with project `dhealth-fb17e` selected (top bar).
2. **Create service account**.
3. Service account name: `clinical-evidence-ci`. The ID should fill in as
   `clinical-evidence-ci`. Email will be
   `clinical-evidence-ci@dhealth-fb17e.iam.gserviceaccount.com`.
4. Description: `GitHub Actions read-only Firestore for the clinical evidence review gate.`
5. **Create and continue**.
6. Grant access: role **Cloud Datastore Viewer** (`roles/datastore.viewer`).
   Do not add Editor, Owner, Firebase Admin, or Cloud Datastore User.
7. **Continue** → skip "Principals with access" → **Done**.
8. Do **not** open the account and create a JSON key.

**Firebase Console** cannot create this IAM binding. Use Google Cloud Console
or `gcloud`. After the SA exists, you can see it under Google Cloud IAM; you
will not see it as a Firebase Auth user.

#### C. Workload Identity Federation (GitHub OIDC)

```
# Project number (not the string id) is required in the provider resource name.
gcloud projects describe dhealth-fb17e --format="value(projectNumber)"
```

Save that number as `PROJECT_NUMBER`. Then:

```
gcloud iam workload-identity-pools create github \
  --project=dhealth-fb17e \
  --location=global \
  --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc github-actions \
  --project=dhealth-fb17e \
  --location=global \
  --workload-identity-pool=github \
  --display-name="GitHub Actions OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository == 'OWNER/REPO'"
```

Allow this repo's GitHub Actions identity to impersonate the service account:

```
gcloud iam service-accounts add-iam-policy-binding \
  clinical-evidence-ci@dhealth-fb17e.iam.gserviceaccount.com \
  --project=dhealth-fb17e \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/OWNER/REPO"
```

Print the provider resource name (this is the GitHub secret value):

```
gcloud iam workload-identity-pools providers describe github-actions \
  --project=dhealth-fb17e \
  --location=global \
  --workload-identity-pool=github \
  --format="value(name)"
```

It looks like:

```
projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/github-actions
```

WIF bindings can take a few minutes to propagate. If the first CI run fails
with `getAccessToken` denied, wait five minutes and re-run.

**Console equivalent for the pool:** IAM & Admin → **Workload Identity
Federation** → Create pool `github` → Add provider → OpenID Connect → issuer
`https://token.actions.githubusercontent.com` → map `google.subject` ←
`assertion.sub`, `attribute.repository` ← `assertion.repository` → attribute
condition `assertion.repository == 'OWNER/REPO'` → connect service account
`clinical-evidence-ci` with attribute `repository` = `OWNER/REPO` (this
grants `roles/iam.workloadIdentityUser`).

### GitHub secrets (you add these)

Repo → **Settings** → **Secrets and variables** → **Actions** → **New
repository secret**. Two secrets:

| Secret name | Value |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Full provider name from the `providers describe` command above |
| `GCP_SERVICE_ACCOUNT` | `clinical-evidence-ci@dhealth-fb17e.iam.gserviceaccount.com` |

These are identifiers, not private keys, but the workflow reads them as
secrets. Do not add a `GOOGLE_CREDENTIALS` / JSON key secret.

Do this **before** the first push of the workflow if you can. Missing secrets
fail the compliance job with a setup error (`exit 2`), which is a different
failure from `never-reviewed`.

No other secrets are required for these four jobs. Citation-identifier checks
do not need Crossref credentials. Optional: set `CITATION_CHECK_CONTACT` in
the identifiers job later (a real email in the User-Agent) if Crossref rate
limits become an issue.

### How to add a new human reviewer

This is **not** a GCP IAM change and **not** a GitHub secret.

1. The person signs in once through the review portal (same Firebase Auth
   project as the mobile app) so `users/{uid}` exists.
2. In **Firebase Console → Firestore → `users` → their Auth UID**, set
   `profile.role` to `clinicalReviewer` (or `clinicalAdmin` for emergency
   actions). Use the exact strings; the client cannot write these values.
3. They can then read the queue and Approve / Reject / Request changes.

Do not grant reviewers `datastore.viewer` on the CI service account, and do
not put their Google accounts on the CI SA. Reviewer power lives in
`profile.role`; CI only lists collections.

To let a **different GitHub repository** run this check, add another
`roles/iam.workloadIdentityUser` binding on the same SA, with that repo in
the `attribute.repository` member path, and tighten or extend the provider
attribute condition.

### How to interpret a CI failure

Open the failed job (not just the overall red X). The Dart scripts print
per-entry `FAIL` blocks to the log; CI does not hide them. GitHub also
annotates the compliance job and writes a job summary.

| What you see | Meaning | What to do |
|---|---|---|
| Job **Analyze** red | `flutter analyze` found issues | Fix Dart analyzer findings. Unrelated to Firestore. |
| Job **Test** red | `flutter test` failed | Fix the failing test. Offline; uses `fake_cloud_firestore` for matching logic. |
| **Verify citation identifiers** + `FAIL` on a DOI/PMID | Identifier does not resolve at Crossref / Europe PMC | Do not "fix" by editing clinical dart files until the dermatologist packet says to. See [`CITATION_AUDIT.md`](CITATION_AUDIT.md). |
| Identifiers job: "registry APIs were unreachable" (`exit 2`) | Network / rate limit | Re-run the job. Not a content failure. |
| **Verify clinical evidence reviews** + `FAIL  never-reviewed` | Live dart row has no matching **approved** review | Expected until a named reviewer approves that `entryRef` + clinical fields. Submit a pending review in the portal, then approve. |
| `FAIL  content-mismatch` | An approved review exists but title/authors/doi/pmid/keyFinding/gradeLevel do not match live data | Live file changed without a new approval, or the approval was for different content. File a new review. |
| `FAIL  disabled-unresolved` | Open emergency `disable` covers this row | Admin must `restored` or `revoked-permanently`; the dart row still fails while it remains in the files. |
| Compliance job: "could not read Firestore" / missing secrets / HTTP 401/403 (`exit 2`) | Auth setup, not content | Check the two GitHub secrets, WIF binding, `roles/datastore.viewer`, and that APIs are enabled. |
| Compliance job skipped | Fork PR | Open a same-repo PR, or push to `main`. |

A failing compliance run against current psoriasis/eczema data (29 live
entries, zero approved reviews) **should fail extensively**. That is the gate
working. Do not "fix" it by editing `lib/data/psoriasis_clinical_data.dart` or
`lib/data/eczema_clinical_data.dart`.

### Blocking vs ignored-red

The workflow **fails** when compliance fails. There is no informational mode
in YAML. Whether that blocks **merge** is a GitHub branch-protection setting
(required checks), not a workflow flag.

Recommended operating stance:

1. Keep the job failing honestly (no `continue-on-error`). Soft-fail "until
   the backlog clears" has no natural end and trains the team to ignore the
   gate.
2. In branch protection, require **Analyze** and **Test** as soon as they are
   green. Add **Verify citation identifiers** when that job is green (it may
   stay red until identifier corrections from the citation audit are
   approved and applied).
3. Do **not** mark **Verify clinical evidence reviews** required until it has
   gone green once (initial dermatologist approvals landed). Until then it
   still runs on every PR as a visible red check named for the real reason.
4. The day a clinical job goes green, add it as a required check. One
   settings change; no YAML change.

If you require the compliance job while it is permanently red, **no** PR can
merge — including crash fixes that never touch clinical data. Teams then
bypass *all* required checks, which is worse than a named, non-required red
job. If you instead `continue-on-error` the job, it will stay optional
forever.

GitHub admin merge bypass remains available for a true emergency; that is
logged. Use that, not a silent skip in YAML.

### Local equivalent of the CI compliance job

```
gcloud auth application-default login
dart run tool/verify_clinical_evidence_reviews.dart
```

Or pass a token explicitly:

```
export FIRESTORE_ACCESS_TOKEN="$(gcloud auth application-default print-access-token)"
dart run tool/verify_clinical_evidence_reviews.dart
```
