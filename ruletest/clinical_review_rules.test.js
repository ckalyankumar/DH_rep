/**
 * Emulator tests for clinicalEvidenceReviews security rules.
 *
 * Requires the Firestore emulator on 127.0.0.1:8080. From repo root:
 *   npx -y firebase-tools@latest emulators:exec --only firestore --project dhealth-fb17e "node ruletest/clinical_review_rules.test.js"
 */
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { serverTimestamp } = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'dhealth-fb17e';
const RULES = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

const SUBMITTER = {
  uid: 'submitter-uid',
  email: 'submitter@dhealth.test',
};
const REVIEWER = {
  uid: 'reviewer-uid',
  email: 'reviewer@dhealth.test',
};
const SAME_PERSON = {
  uid: 'same-person-uid',
  email: 'both@dhealth.test',
};

const ENTRY_REF = {
  condition: 'psoriasis',
  location: 'Trigger: Bacterial Infection (Streptococcal)',
  ordinal: 0,
  title: 'Streptococcal Trigger of Psoriasis',
};
const PROPOSED = {
  title: 'Streptococcal Trigger of Psoriasis',
  authors: 'Baker et al.',
  doi: '10.1016/j.det.2018.08.003',
  keyFinding: 'Throat infections precede psoriasis onset',
};

const VALID_NOTES = 'Confirmed claim against the cited source';

function pendingDoc(submittedBy) {
  return {
    status: 'pending',
    entryRef: ENTRY_REF,
    proposedContent: PROPOSED,
    submittedBy,
    submittedAt: new Date('2026-09-14T12:00:00.000Z'),
    reviewedBy: null,
    reviewedAt: null,
    gradeLevel: null,
    reviewNotes: null,
  };
}

function approvePatch(reviewedBy, notes) {
  const patch = {
    status: 'approved',
    reviewedBy,
    reviewedAt: serverTimestamp(),
    gradeLevel: '1B',
  };
  if (notes !== undefined) patch.reviewNotes = notes;
  return patch;
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('users').doc(REVIEWER.uid).set({
      profile: { role: 'clinicalReviewer' },
    });
    await db.collection('users').doc(SAME_PERSON.uid).set({
      profile: { role: 'clinicalReviewer' },
    });
    await db.collection('users').doc(SUBMITTER.uid).set({
      profile: { role: 'patient' },
    });
    await db
      .collection('clinicalEvidenceReviews')
      .doc('self-approve')
      .set(pendingDoc(SAME_PERSON.email));
    await db
      .collection('clinicalEvidenceReviews')
      .doc('short-notes')
      .set(pendingDoc(SUBMITTER.email));
    await db
      .collection('clinicalEvidenceReviews')
      .doc('padded-notes')
      .set(pendingDoc(SUBMITTER.email));
    await db
      .collection('clinicalEvidenceReviews')
      .doc('good-approve')
      .set(pendingDoc(SUBMITTER.email));
    await db
      .collection('clinicalEvidenceReviews')
      .doc('spoof-reviewer')
      .set(pendingDoc(SUBMITTER.email));
    await db
      .collection('clinicalEvidenceReviews')
      .doc('reject-no-notes')
      .set(pendingDoc(SUBMITTER.email));
  });

  const submitterDb = testEnv
    .authenticatedContext(SUBMITTER.uid, { email: SUBMITTER.email })
    .firestore();
  const reviewerDb = testEnv
    .authenticatedContext(REVIEWER.uid, { email: REVIEWER.email })
    .firestore();
  const sameDb = testEnv
    .authenticatedContext(SAME_PERSON.uid, { email: SAME_PERSON.email })
    .firestore();

  const results = [];

  async function expectAllow(name, fn) {
    try {
      await assertSucceeds(fn());
      console.log('PASS', name);
      results.push(true);
    } catch (e) {
      console.log('FAIL', name, (e.message || String(e)).split('\n')[0]);
      results.push(false);
    }
  }

  async function expectDeny(name, fn) {
    try {
      await assertFails(fn());
      console.log('PASS', name);
      results.push(true);
    } catch (e) {
      console.log('FAIL', name, (e.message || String(e)).split('\n')[0]);
      results.push(false);
    }
  }

  console.log('=== clinicalEvidenceReviews rules (emulator) ===');

  await expectDeny(
    'create with spoofed submittedBy (not auth email) is rejected',
    () =>
      submitterDb.collection('clinicalEvidenceReviews').doc('create-spoof').set({
        status: 'pending',
        entryRef: ENTRY_REF,
        proposedContent: PROPOSED,
        submittedBy: 'ai-session-1',
        submittedAt: serverTimestamp(),
        reviewedBy: null,
        reviewedAt: null,
        gradeLevel: null,
      }),
  );

  await expectAllow(
    'create with submittedBy == auth email is allowed',
    () =>
      submitterDb.collection('clinicalEvidenceReviews').doc('create-ok').set({
        status: 'pending',
        entryRef: ENTRY_REF,
        proposedContent: PROPOSED,
        submittedBy: SUBMITTER.email,
        submittedAt: serverTimestamp(),
        reviewedBy: null,
        reviewedAt: null,
        gradeLevel: null,
      }),
  );

  await expectDeny(
    'self-approval (reviewedBy == submittedBy, same auth email) is rejected',
    () =>
      sameDb
        .collection('clinicalEvidenceReviews')
        .doc('self-approve')
        .update(approvePatch(SAME_PERSON.email, VALID_NOTES)),
  );

  await expectDeny(
    'approve with reviewNotes shorter than 12 chars is rejected',
    () =>
      reviewerDb
        .collection('clinicalEvidenceReviews')
        .doc('short-notes')
        .update(approvePatch(REVIEWER.email, 'short')),
  );

  await expectDeny(
    'approve with 12-space reviewNotes (no real content) is rejected',
    () =>
      reviewerDb
        .collection('clinicalEvidenceReviews')
        .doc('padded-notes')
        .update(approvePatch(REVIEWER.email, '            ')),
  );

  await expectDeny(
    'approve with spoofed reviewedBy (not auth email) is rejected',
    () =>
      reviewerDb
        .collection('clinicalEvidenceReviews')
        .doc('spoof-reviewer')
        .update(approvePatch('someone-else@dhealth.test', VALID_NOTES)),
  );

  await expectAllow(
    'four-eyes approve with notes >= 12 is allowed',
    () =>
      reviewerDb
        .collection('clinicalEvidenceReviews')
        .doc('good-approve')
        .update(approvePatch(REVIEWER.email, VALID_NOTES)),
  );

  await expectAllow(
    'reject without reviewNotes is allowed',
    () =>
      reviewerDb
        .collection('clinicalEvidenceReviews')
        .doc('reject-no-notes')
        .update({
          status: 'rejected',
          reviewedBy: REVIEWER.email,
          reviewedAt: serverTimestamp(),
        }),
  );

  await testEnv.cleanup();

  const failed = results.filter((ok) => !ok).length;
  console.log(`\n${results.length - failed}/${results.length} checks passed.`);
  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
