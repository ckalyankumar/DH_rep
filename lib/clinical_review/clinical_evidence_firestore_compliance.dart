import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhealth/clinical_review/clinical_evidence_catalog.dart';
import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';

/// Loads review + emergency-action collections from a [FirebaseFirestore]
/// (real or [FakeFirebaseFirestore]) and runs [ClinicalEvidenceComplianceChecker].
class ClinicalEvidenceFirestoreCompliance {
  static Future<ComplianceReport> check({
    required FirebaseFirestore firestore,
    required List<LiveClinicalEvidenceSite> liveSites,
  }) async {
    final reviewsSnap = await firestore
        .collection(ClinicalReviewSchema.reviewsCollection)
        .get();
    final actionsSnap = await firestore
        .collection(ClinicalReviewSchema.emergencyActionsCollection)
        .get();

    return ClinicalEvidenceComplianceChecker.check(
      liveSites: liveSites,
      reviews: [
        for (final doc in reviewsSnap.docs)
          ClinicalEvidenceReviewDoc.fromMap(doc.id, doc.data()),
      ],
      emergencyActions: [
        for (final doc in actionsSnap.docs)
          EmergencyActionDoc.fromMap(doc.id, doc.data()),
      ],
    );
  }
}
