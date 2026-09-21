import 'package:cloud_functions/cloud_functions.dart';
import 'package:dhealth/clinical_review_portal/portal_auth.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:flutter/material.dart';

class PortalNoAccessScreen extends StatefulWidget {
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
  State<PortalNoAccessScreen> createState() => _PortalNoAccessScreenState();
}

class _PortalNoAccessScreenState extends State<PortalNoAccessScreen> {
  bool _sending = false;
  String? _result;

  Future<void> _requestAccess() async {
    setState(() {
      _sending = true;
      _result = null;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('requestReviewerAccess');
      await callable.call<Map<String, dynamic>>();
      setState(() => _result = 'Request sent. A clinicalAdmin can approve it '
          'from the portal\'s Reviewers tab.');
    } catch (e) {
      setState(() => _result = 'Could not send the request: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final identity = widget.identity;
    final role = widget.role;
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
                    'Request clinicalReviewer access below, or ask the '
                    'project owner to set users/{yourUid}.profile.role in '
                    'the Firebase console. Either way, the portal itself '
                    'never grants that role — a clinicalAdmin has to '
                    'approve it.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _sending ? null : _requestAccess,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Request reviewer access'),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _result!,
                      style: const TextStyle(fontSize: 13, color: PortalTheme.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
