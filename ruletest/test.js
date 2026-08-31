const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const fs = require('fs');

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: 'dhealth-fb17e',
    firestore: {
      rules: fs.readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // Seed data as an admin (bypasses rules) so we start from known state
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
        patientDisplayName: 'ckalyankumar@gmail.com',
        createdAt: new Date().toISOString(),
        consentedAt: new Date().toISOString(),
      });
    console.log('Seed write complete.');
  });

  // Now simulate the doctor's authenticated read, exactly like the app does
  const doctorContext = testEnv.authenticatedContext('YyQG5IEwRkNuaEvExnymeLHd5Kt1', {
    email: 'kalyan136@rediffmail.com',
  });
  const doctorDb = doctorContext.firestore();

  console.log('--- Attempting doctor query ---');
  try {
    const snap = await doctorDb
      .collection('doctorLinks')
      .doc('kalyan136_at_rediffmail_com')
      .collection('patients')
      .where('status', '==', 'active')
      .get();
    console.log('SUCCESS. Docs found:', snap.size);
    snap.forEach((d) => console.log(' -', d.id, d.data()));
  } catch (e) {
    console.log('FAILED:', e.code, e.message);
  }

  await testEnv.cleanup();
}

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});