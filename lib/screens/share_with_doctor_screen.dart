import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dhealth/models/doctor_patient_link.dart';
import 'package:dhealth/services/doctor_patient_link_service.dart';
import 'package:dhealth/screens/login_screen.dart';
import 'package:dhealth/screens/patient_clinical_thread_screen.dart';

/// Patient flow: Share data with a doctor via email and explicit consent.
///
/// Patient controls access. Doctor view is read-only.
/// This app does not diagnose or prescribe. It is for tracking and education only.
class ShareWithDoctorScreen extends StatefulWidget {
  const ShareWithDoctorScreen({super.key});

  @override
  State<ShareWithDoctorScreen> createState() => _ShareWithDoctorScreenState();
}

class _ShareWithDoctorScreenState extends State<ShareWithDoctorScreen> {
  final DoctorPatientLinkService _linkService = DoctorPatientLinkService();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _consentChecked = false;
  bool _isLoading = false;
  String? _error;
  List<DoctorPatientLink> _links = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadLinks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final links = await _linkService.getLinksForPatient(user.uid);
      setState(() => _links = links);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _addShare() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      setState(() => _error = 'You must confirm consent to share.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _linkService.createLink(
        patientId: user.uid,
        patientDisplayName: user.displayName ?? user.email,
        doctorEmail: _emailController.text.trim().toLowerCase(),
      );
      setState(() {
        _isLoading = false;
        _emailController.clear();
        _consentChecked = false;
      });
      _loadLinks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access granted. Your doctor can now view your reports.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _revoke(DoctorPatientLink link) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
          '${link.doctorEmail} will no longer be able to view your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await _linkService.revokeLink(
        patientId: link.patientId,
        doctorEmail: link.doctorEmail,
      );
      _loadLinks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access revoked.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Share with doctor')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sign in to manage who can view your data.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ).then((_) => _loadLinks()),
          icon: const Icon(Icons.login),
          label: const Text('Sign in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share with doctor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDisclaimer(),
            const SizedBox(height: 24),
            _buildAddForm(),
            const SizedBox(height: 24),
            _buildCurrentShares(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You control who sees your data. Doctors can only view your logs and reports in read-only mode. '
              'You can revoke access at any time.',
              style: TextStyle(fontSize: 12, color: Colors.blue[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Grant access to a doctor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Doctor's email",
                  hintText: 'dermatologist@clinic.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _consentChecked,
                onChanged: (v) => setState(() => _consentChecked = v ?? false),
                title: const Text(
                  'I consent to share my symptom logs and reports with this doctor for care coordination.',
                  style: TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addShare,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(_isLoading ? 'Adding...' : 'Grant access'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentShares() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Doctors with access',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_links.isEmpty)
          Card(
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No doctors have access yet. Add one above.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._links.map((link) {
            final user = FirebaseAuth.instance.currentUser;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.medical_services),
                title: Text(link.doctorEmail),
                subtitle: Text(
                  'Since ${link.consentedAt.toString().substring(0, 10)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: user != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PatientClinicalThreadScreen(
                                    patientId: user.uid,
                                    doctorEmail: link.doctorEmail,
                                  ),
                                ),
                              ).then((_) => _loadLinks())
                          : null,
                      icon: const Icon(Icons.chat_bubble_outline),
                      tooltip: 'Message',
                    ),
                    TextButton(
                      onPressed: () => _revoke(link),
                      child: const Text('Revoke', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
