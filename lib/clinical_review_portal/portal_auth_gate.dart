import 'package:dhealth/clinical_review/clinical_roles.dart';
import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review_portal/portal_auth.dart';
import 'package:dhealth/clinical_review_portal/portal_login_screen.dart';
import 'package:dhealth/clinical_review_portal/portal_no_access_screen.dart';
import 'package:dhealth/clinical_review_portal/portal_shell.dart';
import 'package:flutter/material.dart';

/// Routes by Firebase Auth session + users/{uid}.profile.role from Firestore.
class PortalAuthGate extends StatelessWidget {
  const PortalAuthGate({
    super.key,
    required this.auth,
    required this.service,
  });

  final PortalAuth auth;
  final ClinicalReviewPortalService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PortalIdentity?>(
      stream: auth.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting &&
            !authSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final identity = authSnap.data;
        if (identity == null) {
          return PortalLoginScreen(auth: auth);
        }
        return StreamBuilder<String?>(
          stream: service.roleForUser(identity.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting &&
                !roleSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final role = ClinicalRoles.canonicalize(roleSnap.data);
            if (!ClinicalRoles.isStaff(role)) {
              return PortalNoAccessScreen(
                auth: auth,
                identity: identity,
                role: role ?? roleSnap.data,
              );
            }
            return PortalShell(
              auth: auth,
              service: service,
              identity: identity,
              isAdmin: ClinicalRoles.isAdmin(role),
            );
          },
        );
      },
    );
  }
}
