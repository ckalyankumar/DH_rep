import fs from 'fs';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// Personas we seeded in seed-demo-users.js
const PERSONA_IDS = [
  'demo-maya',
  'demo-raj',
  'demo-priya',
  'demo-arun',
  'demo-kavya',
];

async function exportPersona(db, uid) {
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    console.warn(`WARN: user document not found for ${uid}`);
    return null;
  }

  const profile = userSnap.data();

  const [dailyLogsSnap, weeklyPulsesSnap, proAssessmentsSnap] = await Promise.all([
    userRef.collection('dailyLogs').orderBy('date').get(),
    userRef.collection('weeklyPulses').orderBy('weekStartDate').get(),
    userRef.collection('proAssessments').orderBy('date').get(),
  ]);

  return {
    profile,
    dailyLogs: dailyLogsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    weeklyPulses: weeklyPulsesSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    proAssessments: proAssessmentsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
  };
}

async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    console.warn(
      'WARN: FIRESTORE_EMULATOR_HOST is not set. This script is intended to run against the Firestore emulator.'
    );
  }

  // Match the projectId used in seed-demo-users.js
  initializeApp({ projectId: 'dhealth-fb17e' });
  const db = getFirestore();

  const output = {};

  for (const uid of PERSONA_IDS) {
    console.log(`Exporting ${uid}...`);
    const data = await exportPersona(db, uid);
    if (data) {
      output[uid] = data;
    }
  }

  const outPath = 'demo-users-export.json';
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2), 'utf8');
  console.log(`✅ Wrote ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

