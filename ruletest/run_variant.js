const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

async function run(rulesFile) {
  const rulesText = fs.readFileSync(path.join(__dirname, rulesFile), 'utf8');
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
  const col = doctorDb
    .collection('doctorLinks')
    .doc('kalyan136_at_rediffmail_com')
    .collection('patients');

  const results = {};

  try {
    const snap = await col.where('status', '==', 'active').get();
    results.listWhere = `SUCCESS size=${snap.size}`;
  } catch (e) {
    results.listWhere = `FAILED ${e.code}: ${e.message}`;
  }

  try {
    const snap = await col.get();
    results.listAll = `SUCCESS size=${snap.size}`;
  } catch (e) {
    results.listAll = `FAILED ${e.code}: ${e.message}`;
  }

  try {
    const snap = await col.doc('HOUCOHlgCraEiOXzlUCxj3kTVcZ2').get();
    results.get = `SUCCESS exists=${snap.exists}`;
  } catch (e) {
    results.get = `FAILED ${e.code}: ${e.message}`;
  }

  await testEnv.cleanup();
  return results;
}

async function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node run_variant.js <rules-file>');
    process.exit(1);
  }
  console.log('===', file, '===');
  const results = await run(file);
  for (const [k, v] of Object.entries(results)) {
    console.log(k + ':', v);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
