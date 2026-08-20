# dHealth — Clinical Dermatology Companion

A cross-platform Flutter application that helps patients with **psoriasis** and **eczema (atopic dermatitis)** track symptoms, identify personal triggers, predict flare risk, and collaborate with their dermatologist — all backed by peer-reviewed medical evidence.

> dHealth is an educational companion, not a diagnostic or treatment tool. Always consult a qualified dermatologist for clinical decisions.

---

## Table of Contents

- [Features](#features)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [Configuration](#configuration)
- [Firebase Setup](#firebase-setup)
- [Running the App](#running-the-app)
- [Key Services](#key-services)
- [Supported Platforms](#supported-platforms)

---

## Features

| Feature | Description |
|---------|-------------|
| Daily Symptom Logging | Track mood, itch intensity, stress, lesion severity, affected areas, sleep quality, triggers, and notes |
| Flare Risk Scoring | Deterministic 0–100 risk score with component breakdown and red-flag emergency alerts |
| Clinical Insights | Pearson/Spearman trigger correlation analysis backed by 50+ PubMed citations |
| 7–30 Day Predictions | Flare risk forecast with confidence bands |
| Wearable Integration | Apple Health, Fitbit, Garmin, Oura Ring, Google Fit — auto-prefills daily logs |
| PRO Assessments | POEM (eczema) and DLQI (psoriasis) validated clinical questionnaires |
| Doctor Portal | Secure read-only patient data sharing, clinical messaging, PDF/FHIR download |
| PDF Reports | ABDM-compliant multi-page clinical report |
| FHIR Export | JSON-LD bundle for EHR interoperability |
| Environmental Data | Real-time weather, pollen, and air quality trigger integration |
| ABDM Compliance | ABHA ID support for India's Ayushman Bharat Digital Mission |
| GDPR Compliance | Full user data export and deletion |
| Cross-Platform | Android, iOS, Web, Windows, macOS |

---

## Getting Started

### Prerequisites

- Flutter SDK 3.13+
- Dart 3.x
- Firebase CLI
- A Firebase project (see [Firebase Setup](#firebase-setup))
- API keys for weather, pollen, and air quality (see [Configuration](#configuration))

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd dhealth

# Install dependencies
flutter pub get

# Copy environment file and fill in your API keys
cp .env.example .env
```

---

## Project Structure

```
lib/
├── main.dart                        # Entry point, service init, onboarding gate
├── firebase_options.dart            # Firebase config (auto-generated)
│
├── screens/                         # UI screens
│   ├── home_screen.dart            # Clinical dashboard with live risk badge
│   ├── daily_log_screen.dart       # Daily symptom entry with wearable prefill
│   ├── insights_screen.dart        # Trigger correlations and evidence cards
│   ├── predictions_screen.dart     # Flare risk forecast
│   ├── recommendations_screen.dart # Evidence-backed self-care and treatments
│   ├── reports_screen.dart         # PDF/FHIR report generation
│   ├── doctor_portal_screen.dart   # Doctor's patient list
│   ├── doctor_patient_detail_screen.dart
│   ├── login_screen.dart           # Email + Google Sign-In
│   ├── pro_questionnaire_screen.dart # POEM/DLQI weekly assessment
│   ├── share_with_doctor_screen.dart
│   ├── onboarding/                 # 5-step onboarding flow
│   ├── insights/                   # Detailed correlation matrix
│   ├── wearables/                  # Device pairing UI
│   └── settings/                   # Reminders, condition, data management
│
├── services/                        # Business logic (37+ services)
│   ├── daily_log_service.dart
│   ├── firestore_daily_log_service.dart
│   ├── insight_engine.dart          # Correlation analysis
│   ├── recommendation_service.dart  # Evidence-backed recommendations
│   ├── report_generator_service.dart # PDF generation
│   ├── risk_score_calculator.dart   # 0–100 risk scoring
│   ├── wearable_integration_service.dart
│   ├── wearable_sync_service.dart
│   ├── notification_service.dart
│   ├── environmental_data_service.dart
│   ├── doctor_patient_link_service.dart
│   ├── clinical_messaging_service.dart
│   ├── fhir_bundle_generator.dart
│   └── wearables/                   # Device adapters (6 providers)
│
├── models/                          # Data models (20+)
├── data/                            # Clinical knowledge bases
│   ├── psoriasis_clinical_data.dart # 70+ triggers and treatments
│   ├── eczema_clinical_data.dart    # 60+ triggers and treatments
│   └── disorder_registry.dart
│
├── config/                          # App configuration
│   ├── trigger_taxonomy.dart
│   ├── risk_score_config.dart
│   └── disease_configs.dart
│
├── widgets/                         # Reusable UI components (18+)
├── utils/                           # Helpers (theme, responsive, spacing)
└── background/
    └── wearable_sync_callback.dart  # Workmanager background task
```

---

## Architecture Overview

```
┌──────────────────────────────────────────┐
│             Flutter UI (screens/)         │
└────────────────────┬─────────────────────┘
                     │
┌────────────────────▼─────────────────────┐
│           Services Layer (services/)      │
│  DailyLogService → InsightEngine         │
│  RiskScoreCalculator → Recommendations   │
│  WearableSyncService → Notifications     │
└────────────────────┬─────────────────────┘
                     │
┌────────────────────▼─────────────────────┐
│              Firebase Backend             │
│  Auth │ Firestore │ Storage │ Analytics  │
└──────────────────────────────────────────┘
```

**Data flow for a daily log:**

```
User fills DailyLogScreen
  → DailyLogService (local cache / SharedPreferences)
  → FirestoreDailyLogService (cloud sync)
  → InsightEngine (correlation analysis)
  → RiskScoreCalculator (0–100 flare risk)
  → HomeScreen risk badge + Insights screen
```

**Wearable sync flow:**

```
Workmanager (2:00 AM nightly)
  → WearableSyncService
  → WearableAdapterFactory → Device API
  → DailyWearableAggregate (Firestore)
  → DailyLogScreen prefills sleep/stress fields
  → RiskScoreCalculator applies wearable modifier
```

---

## Configuration

Create a `.env` file in the project root:

```env
WEATHER_API_KEY=your_openweathermap_key
POLLEN_API_KEY=your_pollen_api_key
AIR_QUALITY_API_KEY=your_air_quality_key
```

---

## Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Email/Password + Google Sign-In)
3. Enable **Cloud Firestore** (production mode)
4. Enable **Firebase Storage**
5. Run `flutterfire configure` to regenerate `firebase_options.dart`
6. Deploy Firestore security rules: `firebase deploy --only firestore:rules`
7. Deploy Firestore indexes: `firebase deploy --only firestore:indexes`

---

## Running the App

```bash
# Android / iOS
flutter run

# Web
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Run with Firebase emulator (local development)
firebase emulators:start
flutter run --dart-define=USE_EMULATOR=true
```

---

## Key Services

| Service | File | Responsibility |
|---------|------|----------------|
| InsightEngine | `services/insight_engine.dart` | Pearson/Spearman correlation, pattern detection |
| RiskScoreCalculator | `services/risk_score_calculator.dart` | 0–100 flare risk with component breakdown |
| RecommendationService | `services/recommendation_service.dart` | NICE/EADV guideline-backed suggestions |
| ReportGeneratorService | `services/report_generator_service.dart` | Multi-page ABDM-compliant PDF |
| FhirBundleGenerator | `services/fhir_bundle_generator.dart` | FHIR JSON-LD export |
| WearableSyncService | `services/wearable_sync_service.dart` | Background nightly wearable pull |
| EnvironmentalDataService | `services/environmental_data_service.dart` | Weather, pollen, air quality |
| DoctorPatientLinkService | `services/doctor_patient_link_service.dart` | Access control for doctor sharing |
| ClinicalMessagingService | `services/clinical_messaging_service.dart` | Bidirectional doctor-patient messaging |

---

## Supported Platforms

| Platform | Status |
|----------|--------|
| Android | Supported |
| iOS | Supported |
| Web | Supported |
| Windows | Supported |
| macOS | Supported |

---

## Standards & Compliance

- **ABDM** — Ayushman Bharat Digital Mission (India) with ABHA ID support
- **FHIR** — HL7 FHIR R4 JSON-LD for EHR interoperability
- **GDPR** — Full data export and deletion
- **GRADE** — Evidence quality ratings on all clinical citations
- **POEM** — Patient-Oriented Eczema Measure (validated PRO)
- **DLQI** — Dermatology Life Quality Index (validated PRO)
