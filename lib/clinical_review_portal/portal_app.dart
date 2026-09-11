import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review_portal/portal_auth.dart';
import 'package:dhealth/clinical_review_portal/portal_auth_gate.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:flutter/material.dart';

class ClinicalReviewPortalApp extends StatelessWidget {
  const ClinicalReviewPortalApp({
    super.key,
    this.auth,
    this.service,
  });

  /// Test seam. Production uses [FirebasePortalAuth] (Firebase Auth ID tokens).
  final PortalAuth? auth;

  /// Test seam. Production uses [FirebaseFirestore.instance].
  final ClinicalReviewPortalService? service;

  @override
  Widget build(BuildContext context) {
    final portalAuth = auth ?? FirebasePortalAuth();
    final portalService = service ?? ClinicalReviewPortalService();
    return MaterialApp(
      title: 'DHealth Clinical Review',
      theme: PortalTheme.data,
      themeMode: ThemeMode.light,
      home: PortalAuthGate(
        auth: portalAuth,
        service: portalService,
      ),
    );
  }
}
