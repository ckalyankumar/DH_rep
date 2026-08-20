#!/usr/bin/env node
/**
 * DHealth demo data seed script.
 * Seeds 5 persona users with dailyLogs, weeklyPulses, and proAssessments
 * for the Firestore emulator. Run with:
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node seed-demo-users.js
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// ── DISEASE CONFIGS (from lib/config/disease_configs.dart) ──────────────────
const DISEASE_CONFIGS = {
  psoriasis: {
    commonTriggers: ['Stress', 'Cold weather', 'Infections', 'Certain medications', 'Alcohol consumption'],
    affectedAreas: ['Face', 'Scalp', 'Torso', 'Arms', 'Legs', 'Hands', 'Feet', 'Nails'],
  },
  eczema: {
    commonTriggers: ['Allergens', 'Irritants', 'Stress', 'Weather changes', 'Harsh soaps', 'Certain foods'],
    affectedAreas: ['Face', 'Hands', 'Feet', 'Neck', 'Upper chest', 'Skin folds', 'Behind ears'],
  },
};

// Triggers that map to top-level categories for TriggerProCorrelation (match TriggerNormalizationService lexicon)
const TRIGGERS_FOR_CORRELATION = ['stress', 'cold weather', 'poor sleep', 'alcohol'];

// ── PERSONA DEFINITIONS ─────────────────────────────────────────────────────
const PERSONAS = [
  {
    uid: 'demo-maya',
    name: 'Maya',
    condition: 'psoriasis',
    daysToSeed: 90,
    logDensity: 1.0,
    severityProfile: { itchMin: 0, itchMax: 3, moodMin: 4, moodMax: 5, stressMin: 0, stressMax: 3, lesionWeights: [0.6, 0.35, 0.05, 0], sleepMin: 4, sleepMax: 5, disruptionChance: 0.1 },
    efficacyScoreMin: 8,
    efficacyScoreMax: 9,
    proScoreMin: 2,
    proScoreMax: 5,
    trend: 'stable',
    triggerChance: 0.2,
  },
  {
    uid: 'demo-raj',
    name: 'Raj',
    condition: 'psoriasis',
    daysToSeed: 90,
    logDensity: 1.0,
    severityProfile: { itchMin: 3, itchMax: 6, moodMin: 3, moodMax: 4, stressMin: 4, stressMax: 7, lesionWeights: [0.2, 0.5, 0.25, 0.05], sleepMin: 2, sleepMax: 4, disruptionChance: 0.4 },
    efficacyScoreMin: 5,
    efficacyScoreMax: 7,
    proScoreMin: 5,
    proScoreMax: 12,
    trend: 'stress_correlated',
    triggerChance: 0.6,
  },
  {
    uid: 'demo-priya',
    name: 'Priya',
    condition: 'eczema',
    daysToSeed: 90,
    logDensity: 1.0,
    severityProfile: { itchMin: 5, itchMax: 9, moodMin: 2, moodMax: 3, stressMin: 5, stressMax: 8, lesionWeights: [0, 0.2, 0.4, 0.4], sleepMin: 1, sleepMax: 3, disruptionChance: 0.6 },
    efficacyScoreMin: 3,
    efficacyScoreMax: 5,
    proScoreMin: 12,
    proScoreMax: 22,
    trend: 'severe',
    triggerChance: 0.7,
  },
  {
    uid: 'demo-arun',
    name: 'Arun',
    condition: 'eczema',
    daysToSeed: 90,
    logDensity: 0.4, // ~3x/week → ~38 logs
    severityProfile: { itchMin: 2, itchMax: 6, moodMin: 3, moodMax: 4, stressMin: 2, stressMax: 6, lesionWeights: [0.3, 0.4, 0.25, 0.05], sleepMin: 2, sleepMax: 4, disruptionChance: 0.3 },
    efficacyScoreMin: 5,
    efficacyScoreMax: 7,
    proScoreMin: 6,
    proScoreMax: 14,
    trend: 'variable',
    triggerChance: 0.5,
  },
  {
    uid: 'demo-kavya',
    name: 'Kavya',
    condition: 'psoriasis',
    daysToSeed: 60, // 8+ weeks for TriggerProCorrelation
    logDensity: 1.0,
    severityProfile: { itchMin: 2, itchMax: 5, moodMin: 3, moodMax: 5, stressMin: 2, stressMax: 5, lesionWeights: [0.2, 0.5, 0.25, 0.05], sleepMin: 3, sleepMax: 5, disruptionChance: 0.25 },
    efficacyScoreMin: 6,
    efficacyScoreMax: 8,
    proScoreMin: 4,
    proScoreMax: 10,
    trend: 'improving',
    triggerChance: 0.4,
  },
];

// ── HELPERS ─────────────────────────────────────────────────────────────────
function simpleHash(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) {
    h = ((h << 5) - h) + str.charCodeAt(i) | 0;
  }
  return Math.abs(h);
}

function pick(arr, seed) {
  return arr[seed % arr.length];
}

function range(min, max, seed) {
  return min + (seed % (max - min + 1));
}

function getWeekStart(d) {
  const date = new Date(d);
  const day = date.getDay(); // 0=Sun, 1=Mon, ...
  const diff = day;
  date.setDate(date.getDate() - diff);
  date.setHours(0, 0, 0, 0);
  return date;
}

function toDateStr(d) {
  return d.toISOString().slice(0, 10);
}

function toIso8601(d) {
  return d.toISOString();
}

// ── DAILY LOG GENERATION ────────────────────────────────────────────────────
function generateDailyLog(persona, date, dayIndex) {
  const cfg = DISEASE_CONFIGS[persona.condition];
  const p = persona.severityProfile;
  const seed = simpleHash(persona.uid + dayIndex);

  // Sparse logging: skip days based on logDensity
  if (persona.logDensity < 1 && (seed % 100) >= persona.logDensity * 100) {
    return null;
  }

  let itch = range(p.itchMin, p.itchMax, seed);
  let stress = range(p.stressMin, p.stressMax, seed + 1);
  let mood = range(p.moodMin, p.moodMax, seed + 2);

  // Stress-reactive: correlate itch with stress
  if (persona.trend === 'stress_correlated') {
    itch = Math.min(10, Math.floor(itch * 0.5 + stress * 0.5));
  }
  // Improving: Kavya gets better over time (earlier days = worse)
  if (persona.trend === 'improving') {
    const progress = dayIndex / Math.max(1, persona.daysToSeed - 1);
    itch = Math.max(0, Math.floor(itch * (1 - progress * 0.5)));
    mood = Math.min(5, mood + Math.floor(progress * 1.5));
  }

  const lesionRand = (seed + 3) % 100;
  const levels = ['none', 'mild', 'moderate', 'severe'];
  let cum = 0;
  let lesionSeverity = 'none';
  for (let i = 0; i < p.lesionWeights.length; i++) {
    cum += p.lesionWeights[i] * 100;
    if (lesionRand < cum) {
      lesionSeverity = levels[i];
      break;
    }
  }

  const sleepQuality = range(p.sleepMin, p.sleepMax, seed + 4);
  const sleepDisruption = (seed + 5) % 100 < p.disruptionChance * 100;

  const numAreas = Math.min(cfg.affectedAreas.length, range(0, persona.trend === 'severe' ? 6 : 3, seed + 6));
  const affectedAreas = cfg.affectedAreas.slice(0, numAreas).sort(() => (seed % 2) - 0.5);

  const triggers = [];
  if ((seed + 7) % 100 < persona.triggerChance * 100) {
    triggers.push(pick(TRIGGERS_FOR_CORRELATION, seed));
  }
  if ((seed + 8) % 100 < persona.triggerChance * 50) {
    triggers.push(pick(cfg.commonTriggers, seed + 9));
  }

  const dateStr = toDateStr(date);
  const createdAt = new Date(date);
  createdAt.setHours(12, 0, 0, 0);

  return {
    id: dateStr,
    condition: persona.condition,
    mood,
    itchIntensity: itch,
    stressLevel: stress,
    lesionSeverity,
    affectedAreas,
    sleepQuality,
    sleepDisruption,
    notes: persona.trend === 'severe' && itch >= 7 ? 'Flare day' : '',
    date: toIso8601(date),
    triggers: triggers.length ? triggers : null,
    createdAt: toIso8601(createdAt),
    hasWearableData: false,
  };
}

// ── WEEKLY PULSE GENERATION ─────────────────────────────────────────────────
function generateWeeklyPulse(persona, weekStart) {
  const seed = simpleHash(persona.uid + toDateStr(weekStart));
  const score = range(persona.efficacyScoreMin, persona.efficacyScoreMax, seed);
  return {
    weekStartDate: toIso8601(weekStart),
    score,
    condition: persona.condition,
    createdAt: toIso8601(weekStart),
  };
}

// ── PRO ASSESSMENT GENERATION ───────────────────────────────────────────────
const POEM_ITEMS = [
  { id: 'poem_1', text: 'Over the last week, on how many days has your skin been itchy?', maxScore: 4 },
  { id: 'poem_2', text: 'Over the last week, on how many nights has your sleep been disturbed alongside your skin?', maxScore: 4 },
  { id: 'poem_3', text: 'Over the last week, on how many days has your skin been bleeding?', maxScore: 4 },
  { id: 'poem_4', text: 'Over the last week, on how many days has your skin been weeping or oozing clear fluid?', maxScore: 4 },
  { id: 'poem_5', text: 'Over the last week, on how many days has your skin been cracked?', maxScore: 4 },
  { id: 'poem_6', text: 'Over the last week, on how many days has your skin been flaking off?', maxScore: 4 },
  { id: 'poem_7', text: 'Over the last week, on how many days has your skin felt dry or rough?', maxScore: 4 },
];

const DLQI_ITEMS = [
  { id: 'dlqi_1', text: 'Over the last week, how itchy, sore, painful or stinging has your skin been?', maxScore: 3 },
  { id: 'dlqi_2', text: 'Over the last week, how embarrassed or self-conscious have you been alongside your skin?', maxScore: 3 },
  { id: 'dlqi_3', text: 'Over the last week, how much has your skin interfered with going shopping or looking after your home or garden?', maxScore: 3 },
  { id: 'dlqi_4', text: 'Over the last week, how much has your skin influenced the clothes you wear?', maxScore: 3 },
  { id: 'dlqi_5', text: 'Over the last week, how much has your skin affected any social or leisure activities?', maxScore: 3 },
  { id: 'dlqi_6', text: 'Over the last week, how much has your skin made it difficult for you to do any sport?', maxScore: 3 },
  { id: 'dlqi_7', text: 'Over the last week, has your skin prevented you from working or studying, or made it more difficult?', maxScore: 3 },
  { id: 'dlqi_8', text: 'Over the last week, how much has your skin created problems with your partner, close friends, or relatives?', maxScore: 3 },
  { id: 'dlqi_9', text: 'Over the last week, how much has your skin caused any sexual difficulties?', maxScore: 3 },
  { id: 'dlqi_10', text: 'Over the last week, how much of a problem has the treatment for your skin been?', maxScore: 3 },
];

function poemBand(total) {
  if (total <= 2) return 'clear / almost clear';
  if (total <= 7) return 'mild eczema';
  if (total <= 16) return 'moderate eczema';
  if (total <= 24) return 'severe eczema';
  return 'very severe eczema';
}

function dlqiBand(total) {
  if (total <= 1) return 'no effect on life';
  if (total <= 5) return 'small effect on life';
  if (total <= 10) return 'moderate effect on life';
  if (total <= 20) return 'very large effect on life';
  return 'extremely large effect on life';
}

function generateProAssessment(persona, date, seed) {
  const targetScore = range(persona.proScoreMin, persona.proScoreMax, seed);
  if (persona.condition === 'eczema') {
    const items = POEM_ITEMS;
    const responses = [];
    let remaining = Math.min(28, Math.max(0, targetScore));
    for (let i = 0; i < items.length; i++) {
      const isLast = i === items.length - 1;
      const max = Math.min(items[i].maxScore, remaining);
      const score = isLast ? remaining : range(0, max, seed + i);
      const s = Math.min(score, max);
      remaining -= s;
      responses.push({ itemId: items[i].id, questionText: items[i].text, score: s });
    }
    const totalScore = responses.reduce((sum, r) => sum + r.score, 0);
    return {
      type: 'POEM',
      condition: persona.condition,
      date: toIso8601(date),
      totalScore,
      severityBand: poemBand(totalScore),
      responses,
    };
  } else {
    const items = DLQI_ITEMS;
    const responses = [];
    let remaining = Math.min(30, Math.max(0, targetScore));
    for (let i = 0; i < items.length; i++) {
      const isLast = i === items.length - 1;
      const max = Math.min(items[i].maxScore, remaining);
      const score = isLast ? remaining : range(0, max, seed + i);
      const s = Math.min(score, max);
      remaining -= s;
      responses.push({ itemId: items[i].id, questionText: items[i].text, score: s });
    }
    const totalScore = responses.reduce((sum, r) => sum + r.score, 0);
    return {
      type: 'DLQI',
      condition: persona.condition,
      date: toIso8601(date),
      totalScore,
      severityBand: dlqiBand(totalScore),
      responses,
    };
  }
}

// ── MAIN ───────────────────────────────────────────────────────────────────
async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    console.warn('WARN: FIRESTORE_EMULATOR_HOST not set. Use localhost:8080 for local emulator.');
  }

  initializeApp({ projectId: 'dhealth-fb17e' });
  const db = getFirestore();

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  for (const persona of PERSONAS) {
    console.log(`Seeding ${persona.name} (${persona.uid})...`);

    const userRef = db.collection('users').doc(persona.uid);

    // 1. User profile
    await userRef.set({
      name: persona.name,
      selectedCondition: persona.condition,
      createdAt: toIso8601(new Date(today - persona.daysToSeed * 86400000)),
      lastUpdated: toIso8601(today),
    }, { merge: true });

    // 2. Daily logs
    const logsCol = userRef.collection('dailyLogs');
    let logCount = 0;
    const batchSize = 500;
    let batch = db.batch();

    for (let d = 0; d < persona.daysToSeed; d++) {
      const date = new Date(today);
      date.setDate(date.getDate() - (persona.daysToSeed - 1 - d));
      date.setHours(0, 0, 0, 0);

      const log = generateDailyLog(persona, date, d);
      if (log) {
        const docRef = logsCol.doc(log.id);
        batch.set(docRef, log);
        logCount++;
        if (logCount % batchSize === 0) {
          await batch.commit();
          batch = db.batch();
        }
      }
    }
    if (logCount % batchSize !== 0) await batch.commit();
    console.log(`  dailyLogs: ${logCount}`);

    // 3. Weekly pulses (1 per week)
    const pulsesCol = userRef.collection('weeklyPulses');
    const weeks = new Set();
    for (let d = 0; d < persona.daysToSeed; d++) {
      const date = new Date(today);
      date.setDate(date.getDate() - (persona.daysToSeed - 1 - d));
      weeks.add(toDateStr(getWeekStart(date)));
    }
    for (const ws of weeks) {
      const weekStart = new Date(ws);
      const pulse = generateWeeklyPulse(persona, weekStart);
      await pulsesCol.doc(ws).set(pulse);
    }
    console.log(`  weeklyPulses: ${weeks.size}`);

    // 4. Pro assessments (~1-2 per week)
    const prosCol = userRef.collection('proAssessments');
    let proCount = 0;
    const weekStarts = [...weeks].sort();
    for (let i = 0; i < weekStarts.length; i++) {
      const weekStart = new Date(weekStarts[i]);
      const midWeek = new Date(weekStart);
      midWeek.setDate(midWeek.getDate() + 3);
      const id = `pro-${weekStarts[i]}`;
      const pro = generateProAssessment(persona, midWeek, simpleHash(persona.uid + weekStarts[i]));
      await prosCol.doc(id).set(pro);
      proCount++;
      if (i < weekStarts.length - 1 && (simpleHash(persona.uid + weekStarts[i] + 'b') % 2) === 0) {
        const endWeek = new Date(weekStart);
        endWeek.setDate(endWeek.getDate() + 6);
        const id2 = `pro-${weekStarts[i]}-b`;
        const pro2 = generateProAssessment(persona, endWeek, simpleHash(persona.uid + weekStarts[i] + 'b'));
        await prosCol.doc(id2).set(pro2);
        proCount++;
      }
    }
    console.log(`  proAssessments: ${proCount}`);
  }

  console.log('Done. Start Firestore emulator with: firebase emulators:start --only firestore');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
