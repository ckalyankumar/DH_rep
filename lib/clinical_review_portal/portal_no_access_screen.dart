import 'package:dhealth/clinical_review_portal/portal_auth.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:flutter/material.dart';

class PortalNoAccessScreen extends StatelessWidget {
  const PortalNoAccessScreen({
    super.key,
    required this.auth,
    required this.identity,
    this.role,
  });

  final PortalAuth auth;
  final PortalIdentity identity;
  final String? role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Evidence Review'),
        actions: [
          TextButton(
            onPressed: auth.signOut,
            child: const Text('Sign out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You don’t have access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This portal is only for users whose Firestore profile '
                    'role is clinicalReviewer or clinicalAdmin. Patient and '
                    'doctor accounts cannot see the review queue.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Signed in as: ${identity.actorLabel}',
                    style: const TextStyle(fontSize: 13, color: PortalTheme.muted),
                  ),
                  Text(
                    'uid: ${identity.uid}',
                    style: const TextStyle(fontSize: 12, color: PortalTheme.muted),
                  ),
                  Text(
                    'profile.role: ${role ?? '(missing)'}',
                    style: const TextStyle(fontSize: 13, color: PortalTheme.muted),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ask the project owner to set users/{yourUid}.profile.role '
                    'in the Firebase console. The portal will not grant that '
                    'role itself.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
