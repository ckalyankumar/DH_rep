import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Signed-in identity for the clinical review portal.
class PortalIdentity {
  final String uid;
  final String? email;
  final String? displayName;

  const PortalIdentity({
    required this.uid,
    this.email,
    this.displayName,
  });

  /// Stored on `reviewedBy` / `actionBy`.
  String get actorLabel {
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return uid;
  }

  static PortalIdentity? fromUser(User? user) {
    if (user == null) return null;
    return PortalIdentity(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }
}

/// Auth for the portal. Production uses [FirebaseAuth] (ID tokens) so
/// Firestore security rules see `request.auth` and apply role checks.
///
/// Do not replace this with a service-account or IAM REST client.
abstract class PortalAuth {
  Stream<PortalIdentity?> authStateChanges();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

const _kGoogleWebClientId =
    '495637881278-6a1c6rvih06jkqmlmlnrep71u8ih2ogg.apps.googleusercontent.com';

class FirebasePortalAuth implements PortalAuth {
  FirebasePortalAuth({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<PortalIdentity?> authStateChanges() =>
      _auth.authStateChanges().map(PortalIdentity.fromUser);

  @override
  Future<void> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleSignIn = kIsWeb
        ? GoogleSignIn(clientId: _kGoogleWebClientId)
        : GoogleSignIn(serverClientId: _kGoogleWebClientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google Sign-In returned no ID token');
    }
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: idToken,
      ),
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
