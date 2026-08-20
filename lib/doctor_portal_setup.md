# Doctor Portal Setup

## Overview

The doctor portal provides a read-only view for dermatologists to see linked patients and download ABDM-aligned reports (PDF, FHIR bundle). Patients control access via explicit consent.

## Deployment

### Firestore Rules

Deploy the rules so doctors can read shared patient data:

```bash
firebase deploy --only firestore:rules
```

### Firestore Index (optional)

If using collection group queries, ensure the index exists. Firebase may auto-suggest it when first run. Or deploy:

```bash
firebase deploy --only firestore:indexes
```

## Flow

1. **Patient**: Reports tab → Share icon → Enter doctor email → Consent → Grant access
2. **Doctor**: Login screen → "I'm a doctor — Access doctor portal" → Sign in with email → See linked patients
3. **Doctor**: Tap patient → View read-only logs → Download PDF or FHIR bundle
4. **Clinical messaging**: Patient can tap "Message" on a doctor card (Share with doctor) to open the thread; doctor can tap "Message patient" on patient detail. Both can send messages; doctor messages can include "I reviewed data from [date range]". When doctor views logs or downloads a report, `doctorSession` is updated; patient sees "Dr. X last reviewed your data on [date]".

## Security

- Patient data is only readable by the doctor when `users/{patientId}/sharedWithDoctors/{sanitizedDoctorEmail}` exists with status `active`
- Doctor view never mutates patient data
- Patient can revoke access at any time from Share with doctor screen
- **Clinical messaging**: `doctorSession` (doctor writes, patient reads) and `clinicalMessages` (both read/write when link is active) live under `sharedWithDoctors`. Revoking access removes visibility of the thread.
