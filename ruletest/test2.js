const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const fs = require('fs');

async function main() {
  const rulesText = fs.readFileSync('rules_variant2.rules', 'utf8');

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
  });

  const doctorContext = testEnv.authenticatedContext('YyQG5IEwRkNuaEvExnymeLHd5Kt1', {
    email: 'kalyan136@rediffmail.com',
  });
  const doctorDb = doctorContext.firestore();

  try {
    const snap = await doctorDb
      .collection('doctorLinks')
      .doc('kalyan136_at_rediffmail_com')
      .collection('patients')
      .where('status', '==', 'active')
      .get();
    console.log('SUCCESS. Docs found:', snap.size);
  } catch (e) {
    console.log('FAILED:', e.code, e.message);
  }

  await testEnv.cleanup();
}

main().catch((e) => { console.error(e); process.exit(1); });