import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dhealth/screens/login_screen.dart';
import 'package:dhealth/screens/doctor_portal_screen.dart';
import 'package:dhealth/screens/onboarding/onboarding_screen.dart';
import 'package:dhealth/screens/main_screen.dart';
import 'package:dhealth/services/onboarding_prefs.dart';
import 'package:dhealth/debug_agent_log.dart';

/// Routes the app by [FirebaseAuth.instance.authStateChanges], user role from
/// Firestore `users/{uid}/profile`, and local onboarding completion.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String _roleFromProfile(Map<String, dynamic>? data) {
    final profile = data?['profile'];
    if (profile is Map) {
      final raw = profile['role'];
      if (raw is String) {
        final role = raw.trim().toLowerCase();
        if (role == 'doctor' || role == 'patient') {
          return role;
        }
      }
    }
    return 'patient';
  }

  Widget _buildLoading(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading(context);
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Stream profile so doctor role written after sign-in updates routing.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting &&
                !profileSnapshot.hasData) {
              return _buildLoading(context);
            }

            final role = _roleFromProfile(profileSnapshot.data?.data());
            // #region agent log
            agentDebugLog(
              location: 'auth_gate.dart:build',
              message: 'routing decision',
              hypothesisId: 'H1',
              data: {
                'role': role,
                'profileExists': profileSnapshot.data?.exists ?? false,
              },
            );
            // #endregion
            if (role == 'doctor') {
              return const DoctorPortalScreen();
            }

            return FutureBuilder<bool>(
              future: OnboardingPrefs.isComplete(),
              builder: (context, onboardingSnapshot) {
                if (onboardingSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return _buildLoading(context);
                }

                final onboardingComplete = onboardingSnapshot.data ?? false;
                if (onboardingComplete) {
                  return const MainScreen();
                }
                return OnboardingScreen(onComplete: () {
                  if (mounted) setState(() {});
                });
              },
            );
          },
        );
      },
    );
  }
}
