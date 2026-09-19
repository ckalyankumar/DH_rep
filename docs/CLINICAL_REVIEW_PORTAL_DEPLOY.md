# Deploying the clinical review portal for an external dermatologist

This is the runbook for putting `lib/clinical_review_portal/` in front of a
dermatologist at **https://clinicalreview.pivolt.net**, and loading the
citation-audit findings ([`CITATION_AUDIT.md`](CITATION_AUDIT.md)) into the
review queue so he has something to review the first time he logs in.

Nothing here has been run yet — no deploy, no account creation, no Firestore
writes. Everything below is a command *you* run locally (this environment has
no `gcloud`/`firebase` credentials for this project and no DNS access to
pivolt.net).

---

## 0. What you're deploying

- A **separate** app from the patient/doctor mobile app: same Firebase
  project (`dhealth-fb17e`), same Firestore, different Flutter **entry
  point** (`lib/clinical_review_portal/main.dart`) and a different **Firebase
  Hosting site**, so it gets its own URL and can carry its own custom domain
  without touching whatever (if anything) is already hosted at the project's
  default `dhealth-fb17e.web.app`/`.firebaseapp.com` addresses.
- `firebase.json` now has a `hosting` entry aimed at a hosting **target**
  named `clinical-review-portal`, serving the folder `build/review_portal`.
  That target has to be created once (step 1) before the first deploy.

## 1. One-time Firebase Hosting setup (run once, ever)

From the repo root, signed in to the Firebase CLI as an account with access
to `dhealth-fb17e` (`firebase login` if you haven't already):

```bash
# Create a second Hosting site in this project (the default site is separate
# and untouched). Site IDs are globally unique across all Firebase projects,
# so if this exact name is taken, pick another (e.g. dhealth-clinical-review).
firebase hosting:sites:create dhealth-clinical-review --project dhealth-fb17e

# Point the "clinical-review-portal" target (used in firebase.json) at that site.
firebase target:apply hosting clinical-review-portal dhealth-clinical-review --project dhealth-fb17e
```

This writes a `.firebaserc` target mapping — commit that file (it has no
secrets, just the site-id ↔ target-name mapping).

## 2. Build and deploy

```bash
flutter build web -t lib/clinical_review_portal/main.dart -o build/review_portal

firebase deploy --only hosting:clinical-review-portal --project dhealth-fb17e
```

That deploys to `https://dhealth-clinical-review.web.app` (or whatever
site-id you chose in step 1). Confirm it loads and shows the portal's login
screen before moving to the custom domain — a broken build is much easier to
debug on the `.web.app` URL than mid-DNS-propagation.

**Re-deploying later** (after a portal code change) is just the same two
commands again — the site/target from step 1 only needs to be created once.

## 3. Custom domain: clinicalreview.pivolt.net

In the [Firebase Console](https://console.firebase.google.com/project/dhealth-fb17e/hosting/sites) →
**Hosting** → select the `dhealth-clinical-review` site → **Add custom
domain** → enter `clinicalreview.pivolt.net`.

Firebase will give you DNS records to add at whichever registrar/DNS
provider manages `pivolt.net`:

- Typically an **A record** (or two) pointing `clinicalreview` at Firebase's
  hosting IPs, plus a **TXT record** for domain ownership verification.
- Add those exactly as shown in the console (the specific values are
  generated per-domain and can't be predicted ahead of time).

DNS propagation and Firebase's SSL certificate provisioning can take
anywhere from a few minutes to ~24 hours. The console shows live status
(`Needs setup` → `Pending` → `Connected`) — don't hand the link to the
dermatologist until it shows `Connected` with a valid certificate.

## 4. Create the dermatologist's account (email + password)

Simplest path — no scripting needed:

1. [Firebase Console](https://console.firebase.google.com/project/dhealth-fb17e/authentication/users) →
   **Authentication** → **Users** → **Add user**.
2. Enter his email and a temporary password.
3. Send him the URL (`https://clinicalreview.pivolt.net`), his email, and the
   temporary password through whatever channel you'd normally use to share a
   credential (not this chat/plain email ideally — a password manager share
   link or a phone call is safer). The portal's login screen (email/password
   — see `lib/clinical_review_portal/portal_login_screen.dart`) has no
   "forgot password" self-service flow tied to this specific account by
   default beyond standard Firebase Auth password reset, so consider asking
   him to change it on first login if you want to stop holding it yourself.

## 5. Grant him the `clinicalReviewer` role

He can sign in once his account exists, but the portal will show the "you
don't have access" screen until his role is set. This step **must** be done
from the Firebase Console or Admin SDK — the mobile/web client rules
explicitly block a client from setting this field on itself (see
[`CLINICAL_EVIDENCE_REVIEW.md`](CLINICAL_EVIDENCE_REVIEW.md), "Who may do
what").

1. [Firebase Console](https://console.firebase.google.com/project/dhealth-fb17e/firestore/data) →
   **Firestore Database** → `users` collection → find his document (by uid —
   copy it from the Authentication tab, or have him log into the portal once
   first so the `users/{uid}` doc exists if your login flow creates it on
   first sign-in; check `lib/services/` for where that happens for doctor
   accounts, since the portal reuses the same profile shape).
2. Edit the `profile.role` field to the string `clinicalReviewer`.
3. If you also want yourself as `clinicalAdmin` (to manage emergency
   disables later), do the same for your own `users/{uid}` doc with value
   `clinicalAdmin`.

## 6. Load the citation-audit findings into the review queue

The queue is empty right now (0 approved reviews, per the compliance script
output in [`CLINICAL_EVIDENCE_REVIEW.md`](CLINICAL_EVIDENCE_REVIEW.md)), so
without this step he'd log in and see nothing to review.

`tool/submit_citation_audit_reviews.dart` (new) creates one `pending`
`clinicalEvidenceReviews` document for each of the 29 live citations, with:

- the audit's corrected identifier (title/authors/year/journal/doi/pmid/url)
  where a real replacement paper was found,
- the **live, unmodified** `keyFinding` in both `previousContent` and
  `proposedContent` (this script does not rewrite any clinical claim — see
  the file's header comment for why),
- `reviewNotes` summarizing that entry's specific audit finding, including
  the 3 entries the audit recommends **rejecting outright** (no real source
  exists) and the handful with more than one valid real paper to choose
  between.

Run it once you have a Firebase Auth account in this project — any
signed-in user with an Auth email can create a `pending` review, so this
does not require `clinicalReviewer`/`clinicalAdmin`:

```bash
PORTAL_ADMIN_EMAIL=you@example.com PORTAL_ADMIN_PASSWORD=your-password \
  dart run tool/submit_citation_audit_reviews.dart
```

**Run this as yourself (or any account other than the reviewer's), not as
the dermatologist.** `firestore.rules` (updated 2026-09-14) now requires
`submittedBy` to exactly equal the signed-in account's Auth email, and
blocks approving a review where `reviewedBy == submittedBy` (no
self-approval). If you run this script signed in as the dermatologist's own
account, he will be unable to approve any of the 29 reviews it creates.

Expected output: `Done: 29 submitted, 0 failed, out of 29.` If any fail,
the script prints the Firestore error for that entry — the most likely cause
is signing in with an account that doesn't exist yet in this project (create
one via step 4's console flow, using your own email, before running this).

This is a **one-off, run-once** script (see the "RUN ONCE" note in its
header) — re-running it creates duplicate pending reviews for the same
entries.

## 7. What he'll see, and what happens after he reviews

He logs in, lands on the Review Queue (`review_queue_screen.dart`) with 29
pending items. Opening one (`review_detail_screen.dart`) shows the proposed
vs. previous content, the `reviewNotes` context above, a GRADE selector, and
Approve / Reject / Request Changes.

**Important — this doesn't auto-update the app.** Approving a review in the
portal only marks that Firestore document `approved`; it does not by itself
change `lib/data/psoriasis_clinical_data.dart` /
`eczema_clinical_data.dart`. Someone (you, or a future coding session) still
has to copy each approved entry's final fields into the corresponding dart
file, then `dart run tool/verify_clinical_evidence_reviews.dart` will report
that entry as compliant instead of `never-reviewed`. That hand-copy step is
intentional friction — it's the last point where a human can catch a mistake
before it reaches the dart source the app actually ships.

## Summary checklist

- [ ] `firebase hosting:sites:create` + `target:apply` (step 1, one-time)
- [ ] `flutter build web -t lib/clinical_review_portal/main.dart` + `firebase deploy` (step 2)
- [ ] Add custom domain `clinicalreview.pivolt.net` in Firebase Console + DNS records at your registrar (step 3)
- [ ] Create the dermatologist's Firebase Auth account (step 4)
- [ ] Set his `users/{uid}.profile.role` to `clinicalReviewer` (step 5)
- [ ] Run `tool/submit_citation_audit_reviews.dart` to seed the 29 pending reviews (step 6)
- [ ] Share the URL + credentials with him
