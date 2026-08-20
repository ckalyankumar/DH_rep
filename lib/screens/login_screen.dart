import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:dhealth/services/firestore_user_profile_service.dart';
import 'package:dhealth/debug_agent_log.dart';

/// Web client ID from Google Cloud Console (Firebase Auth > Sign-in method > Google).
/// Required for Google Sign-In on Android; add it if sign-in fails.
const String _kGoogleWebClientId = '495637881278-6a1c6rvih06jkqmlmlnrep71u8ih2ogg.apps.googleusercontent.com';

/// Login screen with separate Patient and Doctor flows.
/// Supports email/password and Google Sign-In. No anonymous login.
class LoginScreen extends StatefulWidget {
  /// Pre-select role when opened from doctor portal.
  final String? initialRole;

  const LoginScreen({super.key, this.initialRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _error;
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  /// 'patient' | 'doctor'
  late String _role;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole == 'doctor' ? 'doctor' : 'patient';
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _persistRoleForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final selected = _role.trim().toLowerCase();
    if (selected == 'doctor') {
      await FirestoreUserProfileService.saveRole(user.uid, 'doctor');
      return;
    }

    // Never downgrade an existing doctor to patient.
    final existingRole = await FirestoreUserProfileService.getRole(user.uid);
    if (existingRole != 'doctor') {
      await FirestoreUserProfileService.saveRole(user.uid, 'patient');
    }
  }

  String _getErrorMessage(dynamic e) {
    debugPrint('Auth error: $e');
    final msg = e.toString().toLowerCase();
    if (msg.contains('network')) return 'No internet connection';
    if (msg.contains('config') || msg.contains('options')) {
      return 'Firebase config error - check firebase_options.dart';
    }
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return 'Invalid email or password';
    }
    if (msg.contains('email-already-in-use')) return 'This email is already registered';
    if (msg.contains('weak-password')) return 'Password should be at least 6 characters';
    if (msg.contains('invalid-email')) return 'Please enter a valid email';
    if (msg.contains('operation-not-allowed')) {
      return 'Sign-in method not enabled. Enable Email/Password and Google in Firebase Console > Authentication > Sign-in method.';
    }
    if (msg.contains('too-many-requests')) return 'Too many attempts. Try again later.';
    if (msg.contains('popup') || msg.contains('redirect')) return 'Sign-in was blocked (popup/redirect). Allow popups for this site.';
    return 'Login failed. Please try again.';
  }

  Future<void> _loginWithEmail() async {
    if (_email.trim().isEmpty || _password.isEmpty) {
      setState(() => _error = 'Enter email and password');
      return;
    }
    if (_isSignUp) {
      if (_password.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters');
        return;
      }
      if (_password != _confirmPassword) {
        setState(() => _error = 'Passwords do not match');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.trim(),
          password: _password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.trim(),
          password: _password,
        );
      }

      // #region agent log
      agentDebugLog(
        location: 'login_screen.dart:_loginWithEmail',
        message: 'email auth success before pop',
        hypothesisId: 'H1',
        data: {
          'uiRole': _role,
          'isSignUp': _isSignUp,
        },
      );
      // #endregion

      await _persistRoleForCurrentUser();

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _getErrorMessage(e);
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final googleSignIn = kIsWeb
          ? GoogleSignIn(
              clientId: _kGoogleWebClientId,
            )
          : GoogleSignIn(
              serverClientId: _kGoogleWebClientId,
            );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _error = 'Google Sign-In failed: no ID token. Enable Google in Firebase Console > Authentication > Sign-in method, and add this domain to Google Cloud Console > APIs & Services > Credentials > Authorized JavaScript origins.';
            _isLoading = false;
          });
        }
        return;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // #region agent log
      agentDebugLog(
        location: 'login_screen.dart:_loginWithGoogle',
        message: 'google auth success before pop',
        hypothesisId: 'H1',
        data: {'uiRole': _role},
      );
      // #endregion

      await _persistRoleForCurrentUser();

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          final msg = e.toString().toLowerCase();
          if (msg.contains('sign_in_canceled') || msg.contains('popup_closed')) {
            _error = null;
          } else {
            _error = _getErrorMessage(e);
          }
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = _role == 'doctor';

    return Scaffold(
      appBar: AppBar(
        title: Text(isDoctor ? 'Doctor Login' : 'Patient Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRoleSelector(),
            const SizedBox(height: 32),
            if (isDoctor) _buildDoctorDisclaimer(),
            if (!isDoctor) _buildPatientDisclaimer(),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _clearError,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            if (_isSignUp) ...[
              const SizedBox(height: 16),
              _buildConfirmPasswordField(),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginWithEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isSignUp ? 'Create account' : 'Sign in'),
              ),
            ),
            const SizedBox(height: 12),
            if (!isDoctor)
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                          _confirmPassword = '';
                        }),
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign in'
                      : "Don't have an account? Sign up",
                ),
              ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            if (!isDoctor)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 24),
                label: const Text('Sign in with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _RoleChip(
                label: "I'm a Patient",
                icon: Icons.person,
                isSelected: _role == 'patient',
                onTap: () => setState(() {
                  _role = 'patient';
                  _error = null;
                  _isSignUp = false;
                  _confirmPassword = '';
                }),
              ),
            ),
            Expanded(
              child: _RoleChip(
                label: "I'm a Doctor",
                icon: Icons.medical_services,
                isSelected: _role == 'doctor',
                onTap: () => setState(() {
                  _role = 'doctor';
                  _error = null;
                  _isSignUp = false;
                  _confirmPassword = '';
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.teal.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Access is read-only. You will only see patients who have explicitly shared their data with you.',
              style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sign in to sync your logs and share reports with your doctor. '
              'This app does not diagnose or prescribe.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'you@example.com',
        prefixIcon: const Icon(Icons.email_outlined),
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      onChanged: (v) {
        _email = v;
        _clearError();
      },
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: _isSignUp ? 'At least 6 characters' : 'Your password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: const OutlineInputBorder(),
      ),
      obscureText: _obscurePassword,
      onChanged: (v) {
        _password = v;
        _clearError();
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Confirm password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        border: const OutlineInputBorder(),
      ),
      obscureText: _obscureConfirm,
      onChanged: (v) {
        _confirmPassword = v;
        _clearError();
      },
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
