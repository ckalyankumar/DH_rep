# DHealth Demo Data Seeding

Seeds 5 persona users with `dailyLogs`, `weeklyPulses`, and `proAssessments` into the **Firestore emulator** for local development and testing.

## Prerequisites

- Node.js 18+
- Firebase CLI (`npm install -g firebase-tools`)
- Java (required by Firestore emulator; run `java -version` to verify)

## Quick start

1. **Install dependencies**

   ```bash
   cd scripts
   npm install
   ```

2. **Start the Firestore emulator** (in a separate terminal)

   ```bash
   firebase emulators:start --only firestore
   ```

3. **Run the seed script**

   ```bash
   set FIRESTORE_EMULATOR_HOST=localhost:8080
   npm run seed
   ```

   On macOS/Linux:

   ```bash
   export FIRESTORE_EMULATOR_HOST=localhost:8080
   npm run seed
   ```

   Or in one line:

   ```bash
   FIRESTORE_EMULATOR_HOST=localhost:8080 node seed-demo-users.js
   ```

## Personas

| UID        | Name  | Condition  | Days | Pattern                             |
|------------|-------|------------|------|-------------------------------------|
| demo-maya  | Maya  | Psoriasis  | 90   | Well-controlled, low severity       |
| demo-raj   | Raj   | Psoriasis  | 90   | Stress-reactive, moderate           |
| demo-priya | Priya | Eczema     | 90   | Severe flares, high risk            |
| demo-arun  | Arun  | Eczema     | 90   | Sparse logger (~3×/week)            |
| demo-kavya | Kavya | Psoriasis  | 60   | Newly diagnosed, improving trend    |

## Collections seeded

- `users/{uid}` — Profile (`name`, `selectedCondition`)
- `users/{uid}/dailyLogs` — Daily symptom logs
- `users/{uid}/weeklyPulses` — Weekly self-efficacy scores (0–10)
- `users/{uid}/proAssessments` — POEM (eczema) or DLQI (psoriasis) assessments

## Connect the Flutter app to the emulator

The Flutter app must connect to the Firestore emulator. Add this before any Firestore usage (e.g. in `main.dart`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// After Firebase.initializeApp()
if (kDebugMode) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}
```

(`kDebugMode` from `package:flutter/foundation.dart`)

## Notes

- Data is written only to the emulator. Production Firestore is not touched.
- UIDs are fixed (`demo-maya`, etc.). The emulator does not enforce Firebase Auth.
- For doctor portal testing (Phase 2), populate `sharedWithDoctors` so the demo doctor can access patient data.
