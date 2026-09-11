/// Role names stored at `users/{uid}.profile.role`.
///
/// `patient` and `doctor` are client-assignable (login flow).
/// `clinicalReviewer` and `clinicalAdmin` are protected: they can only be
/// granted via the Firebase console / Admin SDK, never by the app.
class ClinicalRoles {
  static const patient = 'patient';
  static const doctor = 'doctor';
  static const clinicalReviewer = 'clinicalReviewer';
  static const clinicalAdmin = 'clinicalAdmin';

  static const Set<String> clientAssignable = {patient, doctor};
  static const Set<String> protected = {clinicalReviewer, clinicalAdmin};
  static const Set<String> staff = {clinicalReviewer, clinicalAdmin};

  /// Canonical role from a stored string. Unknown / empty → null.
  static String? canonicalize(Object? raw) {
    if (raw is! String) return null;
    switch (raw.trim().toLowerCase()) {
      case 'patient':
        return patient;
      case 'doctor':
        return doctor;
      case 'clinicalreviewer':
        return clinicalReviewer;
      case 'clinicaladmin':
        return clinicalAdmin;
      default:
        return null;
    }
  }

  static bool isProtected(String? role) {
    final canonical = canonicalize(role) ?? role;
    return canonical != null && protected.contains(canonical);
  }

  static bool isStaff(String? role) {
    final canonical = canonicalize(role) ?? role;
    return canonical != null && staff.contains(canonical);
  }

  static bool isAdmin(String? role) {
    return canonicalize(role) == clinicalAdmin;
  }
}
