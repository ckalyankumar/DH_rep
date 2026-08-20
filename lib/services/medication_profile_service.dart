import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhealth/models/medication_profile.dart';

class MedicationProfileService {
  final FirebaseFirestore _db;

  MedicationProfileService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('medicationProfile')
        .doc('profile');
  }

  Future<MedicationProfile?> getProfile(String uid) async {
    try {
      final snapshot = await _profileDoc(uid).get();
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      data['uid'] ??= uid;
      return MedicationProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(MedicationProfile profile) async {
    await _profileDoc(profile.uid).set(
      profile.toJson(),
      SetOptions(merge: true),
    );
  }

  Stream<MedicationProfile?> watchProfile(String uid) {
    return _profileDoc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      data['uid'] ??= uid;
      return MedicationProfile.fromJson(data);
    });
  }
}

