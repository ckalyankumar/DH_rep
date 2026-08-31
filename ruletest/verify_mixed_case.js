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
    await context.firestore()
      .collection('doctorLinks')
      .doc('kalyan136_at_rediffmail_com')
      .collection('patients')
      .doc('HOUCOHlgCraEiOXzlUCxj3kTVcZ2')
      .set({ patientId: 'HOUCOHlgCraEiOXzlUCxj3kTVcZ2', status: 'active' });
  });

  const mixed = testEnv.authenticatedContext('YyQG5IEwRkNuaEvExnymeLHd5Kt1', {
    email: 'Kalyan136@Rediffmail.Com',
  });

  try {
    const snap = await mixed.firestore()
      .collection('doctorLinks')
      .doc('kalyan136_at_rediffmail_com')
      .collection('patients')
      .where('status', '==', 'active')
      .get();
    console.log('mixed-case token email: SUCCESS size=' + snap.size);
  } catch (e) {
    console.log('mixed-case token email: FAILED', e.code, e.message.split('\n')[0]);
  }

  await testEnv.cleanup();
}

main().catch((e) => { console.error(e); process.exit(1); });
