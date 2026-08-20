import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;

import 'firebase_options.dart';

import 'package:dhealth/services/wearable_sync_prefs.dart';
import 'package:dhealth/services/onboarding_prefs.dart';
import 'package:dhealth/services/firestore_user_profile_service.dart';
import 'package:dhealth/services/notification_service.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/widgets/auth_gate.dart';
import 'package:workmanager/workmanager.dart';
import 'package:dhealth/background/wearable_sync_callback.dart';

/// Delay until next 2:00 AM local time.
Duration _nextSyncDelay() {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, 2, 0);
  if (next.isBefore(now) || next.isAtSameMomentAs(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next.difference(now);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env file not found, using defaults');
  }

  // Initialize Firebase with generated options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized with DefaultFirebaseOptions');

    // Ensure auth persistence on web so sessions survive reloads.
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      debugPrint('FirebaseAuth persistence set to LOCAL (web)');
    }
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // Persist uid for background wearable sync; clear on sign-out
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      await WearableSyncPrefs.setUid(user.uid);
      // Sync onboarding condition to Firestore on first login
      final condition = await OnboardingPrefs.getCondition();
      await FirestoreUserProfileService.saveCondition(user.uid, condition);
    } else {
      await WearableSyncPrefs.clearUid();
    }
  });
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await WearableSyncPrefs.setUid(currentUser.uid);
  }

  // Initialize local notifications (mobile only)
  if (!kIsWeb) {
    try {
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  // Initialize Workmanager for nightly wearable sync (mobile only).
  // In debug, cancel scheduled work and skip periodic registration so background
  // workers do not spawn a second engine while `flutter run` is attached (avoids
  // flaky "Lost connection to device" after WM runs).
  if (!kIsWeb) {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      if (kDebugMode) {
        await Workmanager().cancelAll();
        // Search terminal/logcat for this exact tag to confirm debug path ran.
        debugPrint(
          '[DHealth] Workmanager DEBUG: cancelAll() ran; periodic nightly sync not registered',
        );
      } else {
        await Workmanager().registerPeriodicTask(
          'dhealth.wearable.nightly',
          'wearableNightlySync',
          frequency: const Duration(hours: 24),
          initialDelay: _nextSyncDelay(),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.keep,
        );
      }
    } catch (e) {
      debugPrint('Workmanager init failed: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DHealth',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
