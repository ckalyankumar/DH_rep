const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const PATIENT = 'HOUCOHlgCraEiOXzlUCxj3kTVcZ2';
const DOCTOR_UID = 'YyQG5IEwRkNuaEvExnymeLHd5Kt1';
const DOCTOR_EMAIL = 'kalyan136@rediffmail.com';
const SANITIZED = 'kalyan136_at_rediffmail_com';
const OTHER_UID = 'otherDoctorUid123';

async function main() {
  const rulesFile = process.argv[2] || 'proposed_firestore.rules';
  const rulesText = fs.readFileSync(path.join(__dirname, rulesFile), 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: 'dhealth-fb17e',
    firestore: { rules: rulesText, host: '127.0.0.1', port: 8080 },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const user = db.collection('users').doc(PATIENT);
    await user.collection('sharedWithDoctors').doc(SANITIZED).set({
      doctorEmail: DOCTOR_EMAIL,
      status: 'active',
    });
    await user.collection('medicationExceptions').doc('ex1').set({
      type: 'missed_dose',
      occurredAt: new Date().toISOString(),
      status: 'active',
    });
    await user.collection('flareEvents').doc('fl1').set({
      onsetDate: new Date().toISOString(),
      source: 'patient',
    });
    await user.collection('flareCandidates').doc('cand1').set({
      detectedAt: new Date().toISOString(),
    });
    await user.collection('alertDismissals').doc('proTrajectory').set({
      alertType: 'proTrajectory',
      dismissCount: 1,
    });
    await user.collection('weeklyFocus').doc('wf1').set({
      weekStartDate: new Date().toISOString(),
    });
    await user.collection('proAlertDismissals').doc('legacy').set({
      alertType: 'legacy',
    });
    await user.collection('flareEpisodes').doc('ep1').set({
      onsetDate: new Date().toISOString(),
    });
  });

  const doctor = testEnv.authenticatedContext(DOCTOR_UID, { email: DOCTOR_EMAIL }).firestore();
  const patient = testEnv.authenticatedContext(PATIENT, { email: 'patient@example.com' }).firestore();
  const other = testEnv.authenticatedContext(OTHER_UID, { email: 'other.doc@example.com' }).firestore();

  const userCol = (db, name) => db.collection('users').doc(PATIENT).collection(name);

  async function check(name, fn) {
    try {
      const result = await fn();
      console.log('PASS', name, result ?? '');
      return true;
    } catch (e) {
      const msg = (e.message || String(e)).split('\n')[0];
      console.log('FAIL', name, e.code || '', msg);
      return false;
    }
  }

  async function expectDeny(name, fn) {
    try {
      await fn();
      console.log('FAIL', name, 'UNEXPECTED_ALLOW');
      return false;
    } catch (e) {
      if (e.code === 'permission-denied') {
        console.log('PASS', name, 'denied as expected');
        return true;
      }
      console.log('FAIL', name, e.code || '', (e.message || '').split('\n')[0]);
      return false;
    }
  }

  console.log('===', rulesFile, '===');

  await check('patient write medicationExceptions', async () => {
    await userCol(patient, 'medicationExceptions').doc('ex2').set({ type: 'stop' });
    return 'ok';
  });
  await check('doctor list medicationExceptions', async () => {
    const snap = await userCol(doctor, 'medicationExceptions').get();
    if (snap.size < 1) throw new Error('expected docs, got ' + snap.size);
    return 'size=' + snap.size;
  });
  await expectDeny('doctor write medicationExceptions', () =>
    userCol(doctor, 'medicationExceptions').doc('ex1').set({ hacked: true }),
  );
  await expectDeny('other doctor list medicationExceptions', () =>
    userCol(other, 'medicationExceptions').get(),
  );

  await check('patient write flareEvents', async () => {
    await userCol(patient, 'flareEvents').doc('fl2').set({ onsetDate: '2026-01-01' });
    return 'ok';
  });
  await check('doctor list flareEvents', async () => {
    const snap = await userCol(doctor, 'flareEvents').get();
    if (snap.size < 1) throw new Error('expected docs, got ' + snap.size);
    return 'size=' + snap.size;
  });
  await expectDeny('doctor write flareEvents', () =>
    userCol(doctor, 'flareEvents').doc('fl1').set({ hacked: true }),
  );

  await check('patient read flareCandidates', async () => {
    const snap = await userCol(patient, 'flareCandidates').get();
    if (snap.size < 1) throw new Error('expected docs');
    return 'size=' + snap.size;
  });
  await expectDeny('doctor list flareCandidates', () =>
    userCol(doctor, 'flareCandidates').get(),
  );

  await check('patient read alertDismissals', async () => {
    const snap = await userCol(patient, 'alertDismissals').doc('proTrajectory').get();
    if (!snap.exists) throw new Error('missing');
    return 'exists';
  });
  await expectDeny('doctor list alertDismissals', () =>
    userCol(doctor, 'alertDismissals').get(),
  );

  await check('doctor list weeklyFocus', async () => {
    const snap = await userCol(doctor, 'weeklyFocus').get();
    if (snap.size < 1) throw new Error('expected docs, got ' + snap.size);
    return 'size=' + snap.size;
  });
  await expectDeny('doctor write weeklyFocus', () =>
    userCol(doctor, 'weeklyFocus').doc('wf1').set({ hacked: true }),
  );

  await expectDeny('doctor list dead flareEpisodes', () =>
    userCol(doctor, 'flareEpisodes').get(),
  );
  await expectDeny('doctor list dead proAlertDismissals', () =>
    userCol(doctor, 'proAlertDismissals').get(),
  );

  await testEnv.cleanup();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
