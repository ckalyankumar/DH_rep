// DHealth Clinical Evidence Review portal — Flutter Web entry point.
//
// Run:
//   flutter run -d chrome -t lib/clinical_review_portal/main.dart
//
// ACCESS PATH (this is the point of the portal):
//   Firebase.initializeApp → FirebaseAuth (ID token) → cloud_firestore SDK.
//   Security rules in firestore.rules therefore apply. Role checks
//   (clinicalReviewer / clinicalAdmin on users/{uid}.profile.role) are
//   enforced by those rules, not bypassed.
//
//   Do NOT use the IAM/REST client from
//   tool/verify_clinical_evidence_reviews.dart here. That script is a
//   server-side compliance check; this UI is a human reviewer session.

import 'package:dhealth/clinical_review_portal/portal_app.dart';
import 'package:dhealth/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
  runApp(const ClinicalReviewPortalApp());
}
