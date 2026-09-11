import 'package:dhealth/clinical_review_portal/portal_auth.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:flutter/material.dart';

class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key, required this.auth});

  final PortalAuth auth;

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInEmail() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter email and password');
      return;
    }
    await _run(
      () => widget.auth.signInWithEmail(_email.text, _password.text),
    );
  }

  String _message(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found') || msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      return 'Invalid email or password';
    }
    if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    if (msg.contains('network')) return 'No internet connection';
    return 'Sign-in failed. Use an account that already exists in Firebase Auth.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Clinical Evidence Review',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: PortalTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Staff only. Sign in with Firebase Auth — the same accounts '
                    'as the mobile app. Access is granted by setting '
                    'users/{uid}.profile.role to clinicalReviewer or '
                    'clinicalAdmin in the Firebase console. This portal never '
                    'writes that role.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: PortalTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: PortalTheme.rejected, fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _signInEmail(),
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _busy ? null : _signInEmail,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(widget.auth.signInWithGoogle),
                    child: const Text('Sign in with Google'),
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
