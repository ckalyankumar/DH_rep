# dHealth — Technical Documentation

> Version: 1.0 | Platform: Flutter + Firebase | Last updated: 2026-03-26

---

## Table of Contents

1. [Application Overview](#1-application-overview)
2. [System Architecture](#2-system-architecture)
3. [Tech Stack](#3-tech-stack)
4. [Database Schema](#4-database-schema)
5. [Firestore Security Rules](#5-firestore-security-rules)
6. [Core Services](#6-core-services)
7. [Wearable Integration](#7-wearable-integration)
8. [Clinical Algorithms](#8-clinical-algorithms)
9. [Doctor-Patient Collaboration](#9-doctor-patient-collaboration)
10. [Report Generation](#10-report-generation)
11. [Background Tasks](#11-background-tasks)
12. [Notifications](#12-notifications)
13. [Environmental Data](#13-environmental-data)
14. [Screen Inventory](#14-screen-inventory)
15. [Data Models](#15-data-models)
16. [Clinical Knowledge Bases](#16-clinical-knowledge-bases)
17. [Compliance and Standards](#17-compliance-and-standards)
18. [Configuration Reference](#18-configuration-reference)

---

## 1. Application Overview

dHealth is a clinical dermatology companion app targeting patients with **psoriasis** and **atopic dermatitis (eczema)**. It provides:

- **Structured symptom tracking** — daily logs with 9+ clinical fields
- **Evidence-based trigger identification** — statistical correlation analysis over patient history
- **Flare risk prediction** — deterministic 0–100 risk scoring with 7–30 day forecasting
- **Clinical recommendations** — NICE/EADV guideline-aligned self-care and treatment suggestions
- **Validated PRO questionnaires** — POEM (eczema) and DLQI (psoriasis)
- **Wearable integration** — sleep, HRV, and activity data from 6+ device types
- **Doctor collaboration** — secure data sharing, clinical messaging, PDF/FHIR report export
- **Regulatory compliance** — ABDM (India), FHIR, GDPR, GRADE evidence ratings

The app is **not a diagnostic or treatment tool**. All clinical decisions remain with the patient's dermatologist.

---

## 2. System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Flutter Application                        │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────────────┐ │
│  │   Screens    │  │    Services    │  │      Widgets        │ │
│  │  (UI layer)  │◄─┤ (logic layer)  │  │ (reusable UI)       │ │
│  └──────────────┘  └───────┬────────┘  └─────────────────────┘ │
│                             │                                    │
│  ┌──────────────────────────▼──────────────────────────────┐   │
│  │                     Models / Data                        │   │
│  │     DailyLog │ ProAssessment │ RiskScoreResult │ ...     │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────┬──────────────────────────────────┘
                               │
          ┌────────────────────▼────────────────────┐
          │              Firebase                     │
          │  ┌────────┐ ┌───────────┐ ┌──────────┐ │
          │  │  Auth  │ │ Firestore │ │ Storage  │ │
          │  └────────┘ └───────────┘ └──────────┘ │
          └─────────────────────────────────────────┘
                               │
          ┌────────────────────▼────────────────────┐
          │           External APIs                   │
          │  OpenWeatherMap │ Pollen │ Air Quality    │
          │  Wearable Device APIs (OAuth2)            │
          └─────────────────────────────────────────┘
```

### Service Dependency Graph

```
DailyLogService
    └── FirestoreDailyLogService
            └── InsightEngine
                    ├── TriggerNormalizationService
                    ├── RiskScoreCalculator
                    │       └── WearableRepository (modifier data)
                    └── RecommendationService
                            └── PersonalizationService

WearableIntegrationService
    └── WearableAdapterFactory
            └── [AppleHealth|Fitbit|Garmin|Oura|GoogleFit|Samsung]Adapter
                    └── WearableSyncService (Workmanager)
                            └── DailyWearableAggregate (Firestore)

ReportGeneratorService
    ├── FirestoreDailyLogService
    ├── InsightEngine
    └── FhirBundleGenerator
```

---

## 3. Tech Stack

### Core

| Component | Technology | Version |
|-----------|-----------|---------|
| UI Framework | Flutter | 3.13+ |
| Language | Dart | 3.x |
| State Management | StatefulWidget + Services | — |
| Backend | Firebase | — |

### Firebase Services

| Service | Purpose |
|---------|---------|
| Firebase Auth | Email/password and Google Sign-In for patients and doctors |
| Cloud Firestore | Primary NoSQL database with role-based security rules |
| Firebase Storage | PDF reports and document storage |
| Firebase Analytics | User behavior and event tracking |

### Key Flutter Packages

| Package | Version | Purpose |
|---------|---------|---------|
| firebase_auth | 5.1.3 | Authentication |
| cloud_firestore | 5.1.1 | Database |
| firebase_storage | 12.0.4 | File storage |
| google_sign_in | 6.2.2 | OAuth Google login |
| fl_chart | 0.68.0 | Charts and graphs |
| syncfusion_flutter_charts | 25.1.35 | Advanced clinical charts |
| table_calendar | 3.0.9 | Calendar view for logs |
| pdf | 3.11.1 | PDF report generation |
| workmanager | 0.6.0 | Background task scheduling |
| flutter_local_notifications | 17.2.3 | Push notifications |
| shared_preferences | 2.2.2 | Local key-value storage |
| http | 1.2.0 | External API calls |
| flutter_dotenv | 6.0.0 | Environment variable loading |
| permission_handler | 11.3.1 | Device permission management |
| google_fonts | 6.2.1 | Typography |
| intl | 0.18.1 | Internationalization and date formatting |
| url_launcher | 6.2.5 | Opening PubMed links in browser |

---

## 4. Database Schema

All patient data is stored under `users/{uid}/` with sub-collections for each data type. Firestore security rules enforce strict role-based access.

### Top-Level Collections

```
users/{uid}/
├── profile                          # User demographics and settings
├── dailyLogs/{logId}               # Daily symptom entries
├── weeklyPulses/{pulseId}          # Weekly self-efficacy responses
├── proAssessments/{assessmentId}   # POEM / DLQI scores
├── medicationProfile/{docId}       # Current treatment details
├── weeklyFocus/{docId}             # Weekly behavioral goal
├── proAlertDismissals/{docId}      # Dismissed clinical alert records
├── wearableSources/{sourceId}      # Connected wearable metadata
├── dailyWearableAggregates/{date}  # Daily HRV, sleep, steps, stress
├── syncAuditLog/{recordId}         # Wearable sync audit trail
├── redFlagAcknowledgements/{docId} # Emergency red-flag acknowledgements
├── reports/{reportId}              # Generated report metadata
└── sharedWithDoctors/{sanitizedDoctorEmail}/
    ├── clinicalMessages/{msgId}    # Bidirectional messaging thread
    └── doctorSession               # Doctor's last review timestamp
```

### DailyLog Document

```dart
{
  id: String,                        // Auto-generated Firestore ID
  userId: String,                    // Firebase Auth UID
  date: Timestamp,                   // Log date
  mood: int,                         // 1–5 scale
  itchIntensity: int,                // 0–10
  stressLevel: int,                  // 0–10
  lesionSeverity: String,            // 'none' | 'mild' | 'moderate' | 'severe'
  affectedAreas: List<String>,       // Body regions
  sleepQuality: int,                 // 1–5 scale
  sleepDisrupted: bool,
  triggers: List<String>,            // Canonical trigger IDs (e.g. "stress/work")
  notes: String,
  // Wearable-derived fields
  wearablePrefilled: bool,
  wearableProvider: String?,         // 'fitbit' | 'garmin' | 'oura' | ...
  wearableSleepMinutes: int?,
  wearableHrv: double?,
  wearableSteps: int?,
  wearablePrefillSyncedAt: Timestamp?,
  wearableOverrideAudit: Map<String, dynamic>?,  // Fields user overrode
  createdAt: Timestamp,
}
```

### ProAssessment Document

```dart
{
  id: String,
  userId: String,
  type: String,                      // 'POEM' | 'DLQI'
  scores: Map<String, int>,          // Question ID → score
  totalScore: int,
  severity: String,                  // 'clear' | 'mild' | 'moderate' | 'severe'
  mcidThresholdMet: bool,            // Minimal clinically important difference
  biologicEligibilityFlag: bool,     // DLQI ≥ 10 (psoriasis)
  completedAt: Timestamp,
}
```

### DailyWearableAggregate Document (keyed by date: `YYYY-MM-DD`)

```dart
{
  date: String,
  userId: String,
  provider: String,
  totalSleepMinutes: int?,
  deepSleepMinutes: int?,
  remSleepMinutes: int?,
  awakenings: int?,
  hrv: double?,
  restingHeartRate: int?,
  steps: int?,
  activeMinutes: int?,
  stressScore: double?,              // Device-derived if available
  syncedAt: Timestamp,
}
```

---

## 5. Firestore Security Rules

Key rules enforced in `firestore.rules`:

```
// Patients can only read/write their own data
match /users/{uid}/{document=**} {
  allow read, write: if request.auth.uid == uid;
}

// Doctors can read patient data only if an active link exists
match /users/{patientUid}/dailyLogs/{logId} {
  allow read: if isDoctorLinkedToPatient(patientUid);
}

function isDoctorLinkedToPatient(patientUid) {
  let sanitizedEmail = sanitize(request.auth.token.email);
  let link = get(/databases/$(database)/documents/users/$(patientUid)
                  /sharedWithDoctors/$(sanitizedEmail));
  return link != null && link.data.status == 'active';
}
```

Doctors have **read-only** access to: `dailyLogs`, `proAssessments`, `medicationProfile`.
Doctors can **read and write** to: `clinicalMessages`, `doctorSession`.

---

## 6. Core Services

### InsightEngine (`services/insight_engine.dart`)

Analyzes the patient's log history to identify statistically significant trigger correlations.

- Requires minimum **10 logs** before generating insights
- Uses **Pearson correlation** for linear relationships (e.g., stress → itch)
- Uses **Spearman rank correlation** for ordinal variables
- Produces ranked trigger list with correlation coefficients and p-values
- Maps each trigger to clinical evidence (PMID/DOI citations)

### RiskScoreCalculator (`services/risk_score_calculator.dart`)

Produces a deterministic 0–100 flare risk score.

**Score components:**
| Component | Max Points | Source |
|-----------|-----------|--------|
| Itch intensity | 20 | Daily log |
| Stress level | 18 | Daily log |
| Lesion severity | 15 | Daily log |
| Mood (inverse) | 10 | Daily log |
| Sleep quality (inverse) | 10 | Daily log |
| Trend modifier | ±10 | Recent log trajectory |
| Wearable modifier | ±10 | HRV, sleep deficit |
| Environmental modifier | ±7 | Weather, pollen, AQI |

**Risk bands:**
- 0–29: Low
- 30–49: Moderate
- 50–69: Elevated
- 70–100: High (triggers red-flag banner)

### RecommendationService (`services/recommendation_service.dart`)

Generates personalized self-care recommendations and treatment reminders.

- Matches patient's top correlated triggers to evidence-backed interventions
- Ranks recommendations by GRADE evidence level and treatment efficacy
- Separates **doctor-prescribed** (current medication) from **self-care** suggestions
- References NICE (UK) and EADV (Europe) clinical guidelines

### TriggerNormalizationService (`services/trigger_normalization_service.dart`)

Canonicalizes trigger strings across the analytics pipeline. Raw trigger text is mapped to a structured `category/subcategory` ID (e.g. `"stress/work"`, `"diet/dairy"`, `"environment/cold"`).

### PersonalizationService (`services/personalization_service.dart`)

Ranks recommendations based on the patient's individual trigger profile and historical response patterns.

---

## 7. Wearable Integration

### Supported Devices

| Provider | Adapter | Data Retrieved |
|---------|---------|----------------|
| Apple Health | `apple_health_adapter.dart` | Sleep, HRV, steps, active minutes |
| Fitbit | `fitbit_adapter.dart` | Sleep stages, HRV, steps, resting HR |
| Garmin | `garmin_adapter.dart` | Sleep, HRV, stress score, steps |
| Oura Ring | `oura_adapter.dart` | Sleep stages, HRV, readiness score |
| Google Fit | `google_fit_adapter.dart` | Sleep, steps, active minutes |
| Samsung Health | `samsung_adapter.dart` | Sleep, steps, stress |

### Architecture

The wearable system uses an **adapter pattern**:

```
WearableAdapterFactory.forProvider(provider)
    → returns WearableAdapter (abstract interface)
    → concrete adapter handles OAuth2 and API calls
    → returns WearableData { sleep, hrv, steps, stress }
```

### Sync Flow

1. **Nightly sync**: Workmanager triggers `wearableSyncCallback` at 2:00 AM (mobile only)
2. **Manual sync**: Available on-demand from Connect Devices screen (all platforms)
3. Data stored as `DailyWearableAggregate` documents in Firestore
4. Sync events written to `syncAuditLog` for transparency
5. `DailyLogScreen` reads today's aggregate to prefill fields
6. User can **override** any prefilled value; overrides are recorded in `wearableOverrideAudit`

### HRV → Stress Derivation

```
if hrv < 20ms    → stressLevel = 9–10 (very high)
if hrv 20–40ms   → stressLevel = 6–8  (high)
if hrv 40–60ms   → stressLevel = 4–5  (moderate)
if hrv 60–80ms   → stressLevel = 2–3  (low)
if hrv > 80ms    → stressLevel = 0–1  (very low)
```

### Sleep → Sleep Quality Derivation

```
sleepQuality = clamp((totalSleepMinutes / 480) * 5, 1, 5)
// 480 minutes = 8 hours reference
```

---

## 8. Clinical Algorithms

### Trigger Taxonomy

Two-level hierarchy defined in `config/trigger_taxonomy.dart`:

```
stress/
  ├── stress/work
  ├── stress/personal
  └── stress/anxiety
sleep/
  ├── sleep/poor
  ├── sleep/late
  └── sleep/disrupted
diet/
  ├── diet/dairy
  ├── diet/gluten
  ├── diet/alcohol
  └── diet/spicy
environment/
  ├── environment/cold
  ├── environment/heat
  ├── environment/humidity
  ├── environment/pollen
  └── environment/pollution
skincare/
  ├── skincare/soap
  ├── skincare/fragrance
  └── skincare/new_product
activity/
  ├── activity/exercise
  └── activity/sweat
```

### Clinical Knowledge Bases

- `data/psoriasis_clinical_data.dart` — 70+ triggers, treatments, GRADE-rated evidence entries
- `data/eczema_clinical_data.dart` — 60+ triggers, treatments, GRADE-rated evidence entries
- `data/india_pollution_recommendations.dart` — India-specific air quality interventions
- `data/disorder_registry.dart` — Dispatcher that returns the correct clinical dataset per condition

Each evidence entry contains:
```dart
ClinicalEvidence {
  title: String,
  summary: String,
  pmid: String?,       // PubMed ID
  doi: String?,
  gradeLevel: String,  // 'A' | 'B' | 'C' | 'D'
  year: int,
}
```

### Risk Score Configuration (`config/risk_score_config.dart`)

- Component weights
- Band thresholds
- Red-flag trigger conditions (e.g., signs of infection, systemic symptoms)

---

## 9. Doctor-Patient Collaboration

### Access Control Flow

```
1. Patient: ShareWithDoctorScreen → enters doctor email
2. System: sanitizes email (replaces @ and . with _)
3. Firestore write: users/{patientUid}/sharedWithDoctors/{sanitizedEmail}
   { doctorEmail, grantedAt, status: 'active' }

4. Doctor: logs in with matching email
5. DoctorPortalScreen: queries collection group 'sharedWithDoctors'
   where status == 'active' and doctorEmail == auth.token.email
6. Returns list of linked patient UIDs

7. Firestore security rule 'isDoctorLinkedToPatient' checks for active link
   before allowing read access to patient sub-collections

8. Patient revokes: deletes sharedWithDoctors document → immediate access loss
```

### Doctor Capabilities

| Action | Permitted |
|--------|-----------|
| Read daily logs | Yes (read-only) |
| Read PRO assessments | Yes (read-only) |
| Read medication profile | Yes (read-only) |
| Write/edit patient logs | No |
| Send clinical messages | Yes |
| Download PDF report | Yes |
| Download FHIR bundle | Yes |
| View doctor session timestamp | Yes |

### Clinical Messaging

- Stored at `users/{patientUid}/sharedWithDoctors/{sanitizedEmail}/clinicalMessages/{msgId}`
- Both patient and doctor can send messages
- Thread is visible only while the link is active
- Doctor can annotate with "reviewed data from [date range]"
- DoctorSession document tracks doctor's last review timestamp

---

## 10. Report Generation

### PDF Report (`services/report_generator_service.dart`)

ABDM-compliant multi-page clinical report including:

- Patient demographics (name, DOB, ABHA ID, condition)
- Selected date range (7d / 30d / 90d / all)
- Symptom trend charts (itch, stress, mood over time)
- Top identified triggers with correlation strength
- POEM/DLQI assessment history and severity trend
- Current medication/treatment
- Flare risk score history
- Personalized recommendations summary
- Clinical evidence citations

### FHIR Bundle (`services/fhir_bundle_generator.dart`)

Exports a **HL7 FHIR R4 JSON-LD bundle** for EHR interoperability:

```json
{
  "resourceType": "Bundle",
  "type": "document",
  "entry": [
    { "resource": { "resourceType": "Patient", ... } },
    { "resource": { "resourceType": "Observation", ... } },  // daily logs
    { "resource": { "resourceType": "QuestionnaireResponse", ... } }, // PROs
    { "resource": { "resourceType": "Condition", ... } }
  ]
}
```

---

## 11. Background Tasks

Background processing is handled by **Workmanager** (`workmanager: 0.6.0`).

### Registered Tasks

| Task Name | Schedule | Platform | Description |
|-----------|---------|---------|-------------|
| `wearableSyncTask` | Daily at 2:00 AM | Android, iOS | Pull wearable data for all connected devices |

### Callback Dispatcher

`lib/background/wearable_sync_callback.dart` is registered as the Workmanager callback entry point. It:
1. Reads the stored UID from `WearableSyncPrefs` (SharedPreferences)
2. Initializes Firebase
3. Calls `WearableSyncService.syncNightly(uid)`
4. Writes a `SyncAuditRecord` on completion

> Web platform does not support Workmanager. Wearable sync on web is manual only.

---

## 12. Notifications

Handled by `flutter_local_notifications` + `timezone` packages.

### Notification Types

| Type | Trigger | Content |
|------|---------|---------|
| Daily reminder | User-configured time | "Time to log your symptoms" |
| Weekly PRO reminder | Weekly on user-configured day | "Your weekly POEM/DLQI questionnaire is ready" |
| Red-flag alert | Risk score > 70 | Condition-specific emergency guidance |

### Notification Service (`services/notification_service.dart`)

- Schedules recurring daily reminders using `zonedSchedule`
- Stores notification payload for pending-notification handling on app resume
- Respects platform permission model (Android 13+, iOS)

---

## 13. Environmental Data

`services/environmental_data_service.dart` fetches real-time data from three external APIs:

| API | Data | Used For |
|-----|------|---------|
| OpenWeatherMap | Temperature, humidity, UV index, wind | Weather-based trigger detection |
| Pollen API | Pollen count by type (grass, tree, weed) | Pollen trigger correlations |
| Air Quality API | AQI, PM2.5, PM10, NO2, O3 | Pollution risk modifier |

Data is used to:
- Pre-populate environmental triggers in the daily log
- Apply environmental modifier to the risk score
- Surface condition-specific pollution recommendations (India dataset)

API keys are loaded from `.env` via `flutter_dotenv`.

---

## 14. Screen Inventory

| Screen | File | Role | Auth Required |
|--------|------|------|--------------|
| Login | `screens/login_screen.dart` | Email + Google auth | No |
| Onboarding | `screens/onboarding/onboarding_screen.dart` | 5-step setup | Yes |
| Home | `screens/home_screen.dart` | Dashboard with risk badge | Yes (patient) |
| Daily Log | `screens/daily_log_screen.dart` | Symptom entry | Yes (patient) |
| Insights | `screens/insights_screen.dart` | Correlation analysis | Yes (patient) |
| Trigger Correlations | `screens/insights/trigger_correlations_screen.dart` | Detailed matrix | Yes (patient) |
| Predictions | `screens/predictions_screen.dart` | 7–30 day forecast | Yes (patient) |
| Recommendations | `screens/recommendations_screen.dart` | Evidence-backed advice | Yes (patient) |
| PRO Questionnaire | `screens/pro_questionnaire_screen.dart` | POEM / DLQI | Yes (patient) |
| Reports | `screens/reports_screen.dart` | PDF / FHIR export | Yes (patient) |
| Share with Doctor | `screens/share_with_doctor_screen.dart` | Grant/revoke access | Yes (patient) |
| Patient Clinical Thread | `screens/patient_clinical_thread_screen.dart` | Patient messaging | Yes (patient) |
| Connect Devices | `screens/wearables/connect_devices_screen.dart` | Wearable pairing | Yes (patient) |
| Settings | `screens/settings/settings_screen.dart` | App configuration | Yes (patient) |
| Doctor Portal | `screens/doctor_portal_screen.dart` | Patient list | Yes (doctor) |
| Doctor Patient Detail | `screens/doctor_patient_detail_screen.dart` | Read-only patient view | Yes (doctor) |
| Doctor Clinical Thread | `screens/doctor_clinical_thread_screen.dart` | Doctor messaging | Yes (doctor) |

---

## 15. Data Models

| Model | File | Description |
|-------|------|-------------|
| DailyLog | `models/daily_log.dart` | Daily symptom entry |
| ProAssessment | `models/pro_assessment.dart` | POEM / DLQI scores |
| UserProfile | `models/user_profile.dart` | Patient demographics |
| MedicationProfile | `models/medication_profile.dart` | Current treatment |
| WeeklyFocus | `models/weekly_focus.dart` | Behavioral goal |
| WeeklySelfEfficacyPulse | `models/weekly_self_efficacy_pulse.dart` | Confidence rating |
| DailyWearableAggregate | `models/daily_wearable_aggregate.dart` | Aggregated wearable metrics |
| WearableSource | `models/wearable_source.dart` | Connected device metadata |
| SyncAuditRecord | `models/sync_audit_record.dart` | Sync event log |
| DoctorPatientLink | `models/doctor_patient_link.dart` | Access control metadata |
| DoctorSession | `models/doctor_session.dart` | Doctor review tracking |
| ClinicalMessage | `models/clinical_message.dart` | Messaging thread entry |
| RiskScoreResult | `models/risk_score_result.dart` | Risk calculation output |
| ClinicalEvidence | `models/clinical_evidence_models.dart` | Evidence citation |
| RecommendationModel | `models/recommendation_model.dart` | Recommendation entry |

---

## 16. Clinical Knowledge Bases

### Psoriasis (`data/psoriasis_clinical_data.dart`)

- 70+ documented triggers with canonical IDs
- Treatments: biologics (TNF-α, IL-17, IL-23 inhibitors), topical corticosteroids, phototherapy, systemic agents (methotrexate, cyclosporine), lifestyle interventions
- DLQI threshold: score ≥ 10 flags biologic eligibility
- Evidence references: NICE TA guidelines, EADV consensus statements, Cochrane reviews

### Eczema / Atopic Dermatitis (`data/eczema_clinical_data.dart`)

- 60+ documented triggers with canonical IDs
- Treatments: emollients, topical corticosteroids, calcineurin inhibitors, dupilumab, phototherapy, wet wraps, elimination diets
- POEM scoring bands: clear (0–2), mild (3–7), moderate (8–16), severe (17–24), very severe (25–28)
- Evidence references: NICE eczema guidelines, EADV guidelines, AAD guidelines

### India Pollution Recommendations (`data/india_pollution_recommendations.dart`)

- AQI-stratified recommendations specific to Indian pollution conditions
- References CPCB (Central Pollution Control Board) guidelines
- Includes indoor triggers and protective measures

---

## 17. Compliance and Standards

| Standard | Implementation |
|---------|----------------|
| **ABDM** | ABHA ID field in user profile; ABDM-compliant PDF report format |
| **FHIR R4** | JSON-LD bundle export via FhirBundleGenerator |
| **GDPR** | Full data export (CSV) and account/data deletion service |
| **GRADE** | All clinical evidence entries carry A/B/C/D GRADE rating |
| **POEM** | Validated 7-item eczema-specific PRO with MCID tracking |
| **DLQI** | Validated 10-item quality-of-life index; biologic eligibility threshold (≥10) |

---

## 18. Configuration Reference

### Environment Variables (`.env`)

| Variable | Purpose |
|---------|---------|
| `WEATHER_API_KEY` | OpenWeatherMap API key |
| `POLLEN_API_KEY` | Pollen data API key |
| `AIR_QUALITY_API_KEY` | Air quality index API key |

### Firebase Configuration

Firebase config is in `firebase_options.dart` (auto-generated by `flutterfire configure`):

- Project ID: `dhealth-fb17e`
- Per-platform App IDs for Android, iOS, Web, macOS, Windows
- Storage bucket, messaging sender ID

### App Configuration Files

| File | Purpose |
|------|---------|
| `config/trigger_taxonomy.dart` | Two-level trigger hierarchy |
| `config/risk_score_config.dart` | Risk score weights and thresholds |
| `config/disease_configs.dart` | Per-condition feature flags |
| `config/clinical_language_policy.dart` | Approved clinical phrasing |

### Firestore Indexes (`firestore.indexes.json`)

Composite indexes defined for:
- `dailyLogs` by `userId + date` (descending)
- `proAssessments` by `userId + completedAt` (descending)
- `sharedWithDoctors` collection group by `doctorEmail + status`
