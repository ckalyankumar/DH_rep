const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

async function main() {
  const rulesText = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: 'dhealth-fb17e',
    firestore: {
      rules: rulesText,
      host: '127.0.0.1',
      port: 8080,
    },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db
      .collection('doctorLinks')
      .doc('kalyan136_at_rediffmail_com')
      .collection('patients')
      .doc('HOUCOHlgCraEiOXzlUCxj3kTVcZ2')
      .set({
        patientId: 'HOUCOHlgCraEiOXzlUCxj3kTVcZ2',
        doctorEmail: 'kalyan136@rediffmail.com',
        status: 'active',
      });
    await db
      .collection('users')
      .doc('HOUCOHlgCraEiOXzlUCxj3kTVcZ2')
      .collection('sharedWithDoctors')
      .doc('kalyan136_at_rediffmail_com')
      .set({
        doctorEmail: 'kalyan136@rediffmail.com',
        status: 'active',
      });
  });

  const doctorContext = testEnv.authenticatedContext('YyQG5IEwRkNuaEvExnymeLHd5Kt1', {
    email: 'kalyan136@rediffmail.com',
  });
  const otherDoctor = testEnv.authenticatedContext('otherDoctorUid123', {
    email: 'other.doc@example.com',
  });
  const unauth = testEnv.unauthenticatedContext();

  const doctorCol = doctorContext.firestore()
    .collection('doctorLinks')
    .doc('kalyan136_at_rediffmail_com')
    .collection('patients');

  async function check(name, fn) {
    try {
      const result = await fn();
      console.log('PASS', name, result === undefined ? '' : result);
    } catch (e) {
      console.log('FAIL', name, e.code, e.message.split('\n')[0]);
    }
  }

  console.log('=== production firestore.rules ===');

  await check('doctor list where status==active', async () => {
    const snap = await doctorCol.where('status', '==', 'active').get();
    if (snap.size !== 1) throw new Error('expected 1 doc, got ' + snap.size);
    return 'size=' + snap.size;
  });

  await check('doctor get single patient doc', async () => {
    const snap = await doctorCol.doc('HOUCOHlgCraEiOXzlUCxj3kTVcZ2').get();
    if (!snap.exists) throw new Error('missing doc');
    return 'exists';
  });

  await check('doctor read sharedWithDoctors own link', async () => {
    const snap = await doctorContext.firestore()
      .collection('users')
      .doc('HOUCOHlgCraEiOXzlUCxj3kTVcZ2')
      .collection('sharedWithDoctors')
      .doc('kalyan136_at_rediffmail_com')
      .get();
    if (!snap.exists) throw new Error('missing sharedWithDoctors doc');
    return 'exists';
  });

  await check('other doctor list should DENY', async () => {
    try {
      await otherDoctor.firestore()
        .collection('doctorLinks')
        .doc('kalyan136_at_rediffmail_com')
        .collection('patients')
        .where('status', '==', 'active')
        .get();
      throw new Error('UNEXPECTED_ALLOW');
    } catch (e) {
      if (e.message === 'UNEXPECTED_ALLOW') throw e;
      if (e.code === 'permission-denied') return 'denied as expected';
      throw e;
    }
  });

  await check('unauthenticated list should DENY', async () => {
    try {
      await unauth.firestore()
        .collection('doctorLinks')
        .doc('kalyan136_at_rediffmail_com')
        .collection('patients')
        .where('status', '==', 'active')
        .get();
      throw new Error('UNEXPECTED_ALLOW');
    } catch (e) {
      if (e.message === 'UNEXPECTED_ALLOW') throw e;
      if (e.code === 'permission-denied') return 'denied as expected';
      throw e;
    }
  });

  await testEnv.cleanup();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
